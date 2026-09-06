//! macOS 内存清理工具 - Rust 实现
//! 模仿 BuhoCleaner 的清理方式：专注于 Purgeable Space 清理

#![allow(deprecated)] // 允许使用 libc::mach_host_self

use anyhow::{anyhow, Result};
use std::ptr;

/// 内存信息结构
#[derive(Debug, Clone, Copy)]
pub struct MemoryInfo {
    pub total: u64,
    pub free: u64,
    pub used: u64,
    pub active: u64,
    pub inactive: u64,
    pub wired: u64,
    pub compressed: u64,
    pub purgeable: u64,
    pub speculative: u64,
    pub app_memory: u64,
    pub cached_files: u64,
}

impl MemoryInfo {
    /// 获取可清理的内存量（purgeable + inactive file cache）
    pub fn cleanable_space(&self) -> u64 {
        self.purgeable + self.inactive + self.speculative
    }

    /// 获取内存使用百分比
    pub fn used_percent(&self) -> f64 {
        (self.used as f64 / self.total as f64) * 100.0
    }
}

/// 动态获取系统页面大小
pub fn get_page_size() -> Result<u64> {
    let page_size = unsafe { libc::sysconf(libc::_SC_PAGESIZE) };

    if page_size <= 0 {
        // 回退到默认值（Apple Silicon 通常使用 16KB）
        return Ok(16384);
    }

    Ok(page_size as u64)
}

/// 获取总物理内存
pub fn get_total_memory() -> Result<u64> {
    let mut size = std::mem::size_of::<u64>();
    let mut total_memory: u64 = 0;
    let mut mib = [libc::CTL_HW, libc::HW_MEMSIZE];

    let result = unsafe {
        libc::sysctl(
            mib.as_mut_ptr(),
            2,
            &mut total_memory as *mut _ as *mut libc::c_void,
            &mut size,
            ptr::null_mut(),
            0,
        )
    };

    if result != 0 {
        return Err(anyhow!("Failed to get total memory"));
    }

    Ok(total_memory)
}

/// 获取详细内存信息（与 macOS Activity Monitor 一致）
pub fn get_memory_info() -> Result<MemoryInfo> {
    let total = get_total_memory()?;

    let mut vm_stats: libc::vm_statistics64_data_t = unsafe { std::mem::zeroed() };
    let mut count = libc::HOST_VM_INFO64_COUNT;

    let result = unsafe {
        libc::host_statistics64(
            libc::mach_host_self(),
            libc::HOST_VM_INFO64,
            &mut vm_stats as *mut _ as *mut libc::integer_t,
            &mut count,
        )
    };

    if result != libc::KERN_SUCCESS {
        return Err(anyhow!("Failed to get memory statistics: {}", result));
    }

    let page_size = get_page_size()?;

    // 各内存类型
    let active = vm_stats.active_count as u64 * page_size;
    let inactive = vm_stats.inactive_count as u64 * page_size;
    let wired = vm_stats.wire_count as u64 * page_size;
    let speculative = vm_stats.speculative_count as u64 * page_size;
    let purgeable = vm_stats.purgeable_count as u64 * page_size;
    let _free_pages = vm_stats.free_count as u64 * page_size;

    // internal_page_count = anonymous pages (App Memory)
    let internal = vm_stats.internal_page_count as u64 * page_size;
    // external_page_count = file-backed pages (Cached Files)
    let external = vm_stats.external_page_count as u64 * page_size;
    // compressor_page_count = pages occupied by compressor
    let compressor = vm_stats.compressor_page_count as u64 * page_size;

    // === Activity Monitor 计算方式 ===
    // Memory Used = App Memory + Wired Memory + Compressed
    // App Memory = internal_page_count (anonymous/app pages)
    // Wired = wire_count
    // Compressed = compressor_page_count (pages occupied by compressor)

    let app_memory = internal;
    let compressed = compressor;

    // Used = App Memory + Wired + Compressed (Activity Monitor style)
    let used = app_memory + wired + compressed;

    // Free = Total - Used
    let free = total.saturating_sub(used);

    // Cached files
    let cached_files = external;

    Ok(MemoryInfo {
        total,
        free,
        used,
        active,
        inactive,
        wired,
        compressed,
        purgeable,
        speculative,
        app_memory,
        cached_files,
    })
}

/// BuhoCleaner 风格的 Purgeable Space 清理
///
/// 核心策略：
/// 1. 使用 purge 命令清理系统缓存
/// 2. 不使用激进的内存压力策略
/// 3. 温和、安全、不影响系统稳定性
pub fn cleanup_purgeable_space() -> Result<(MemoryInfo, MemoryInfo, f64)> {
    let before = get_memory_info()?;

    // 记录清理前的可清理空间（用于调试）
    let _cleanable_before = before.purgeable + before.speculative;

    // === 阶段 1: purge 命令清理 ===
    // 这是 macOS 官方提供的缓存清理命令
    // BuhoCleaner 主要使用这种方式
    for i in 0..3 {
        let output = std::process::Command::new("purge").output();

        if let Err(e) = output {
            if i == 0 {
                // 如果第一次就失败，可能没有权限
                eprintln!("purge command failed: {}", e);
            }
        }

        // 每次 purge 后短暂等待
        std::thread::sleep(std::time::Duration::from_millis(200));
    }

    // === 阶段 2: 短暂等待让系统整理内存 ===
    // BuhoCleaner 风格：不使用激进的内存压力
    // 只依赖 purge 命令和系统自动回收
    std::thread::sleep(std::time::Duration::from_millis(300));

    // === 阶段 3: 再次 purge 确保清理彻底 ===
    for _ in 0..2 {
        let _ = std::process::Command::new("purge").output();
        std::thread::sleep(std::time::Duration::from_millis(150));
    }

    // 等待系统更新内存统计
    std::thread::sleep(std::time::Duration::from_millis(500));

    let after = get_memory_info()?;

    // 计算释放的内存（BuhoCleaner 风格：主要看 purgeable space 变化）
    let purgeable_freed = before.purgeable.saturating_sub(after.purgeable);
    let speculative_freed = before.speculative.saturating_sub(after.speculative);
    let inactive_freed = before.inactive.saturating_sub(after.inactive);

    // 总释放量
    let total_freed = purgeable_freed + speculative_freed + inactive_freed;

    // 如果 purgeable 方式没效果，使用 used 内存差值
    let freed_bytes = if total_freed > 0 {
        total_freed
    } else if before.used > after.used {
        before.used - after.used
    } else if after.free > before.free {
        after.free - before.free
    } else {
        0
    };

    let freed_mb = freed_bytes as f64 / (1024.0 * 1024.0);

    Ok((before, after, freed_mb))
}

/// 主清理函数（兼容旧接口）
pub fn cleanup_memory() -> Result<(MemoryInfo, MemoryInfo, f64)> {
    cleanup_purgeable_space()
}

/// 获取清理状态描述（BuhoCleaner 风格）
pub fn get_cleanup_status(before: &MemoryInfo, after: &MemoryInfo) -> String {
    let before_percent = before.used_percent();
    let after_percent = after.used_percent();
    let freed_mb = (before.used.saturating_sub(after.used)) as f64 / (1024.0 * 1024.0);

    if freed_mb > 10.0 {
        format!(
            "{:.0}% -> {:.0}% ({:.0}MB freed)",
            before_percent, after_percent, freed_mb
        )
    } else if freed_mb > 0.0 {
        format!("{:.0}% -> {:.0}%", before_percent, after_percent)
    } else {
        format!("Memory OK ({:.0}% used)", after_percent)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_total_memory() {
        let total = get_total_memory().unwrap();
        assert!(total > 0);
        println!("Total memory: {} GB", total / 1024 / 1024 / 1024);
    }

    #[test]
    fn test_get_memory_info() {
        let info = get_memory_info().unwrap();
        assert!(info.total > 0);
        assert!(info.used > 0);
        println!("Memory info:");
        println!("  Total: {:.2} GB", info.total as f64 / 1024.0 / 1024.0 / 1024.0);
        println!("  Used: {:.2} GB ({:.1}%)",
                 info.used as f64 / 1024.0 / 1024.0 / 1024.0,
                 info.used_percent());
        println!("  Purgeable: {:.2} MB", info.purgeable as f64 / 1024.0 / 1024.0);
        println!("  Cleanable: {:.2} MB", info.cleanable_space() as f64 / 1024.0 / 1024.0);
    }

    #[test]
    fn test_cleanup_purgeable_space() {
        let result = cleanup_purgeable_space();
        assert!(result.is_ok());

        let (before, after, freed_mb) = result.unwrap();
        println!("Before: {:.1}% used", before.used_percent());
        println!("After: {:.1}% used", after.used_percent());
        println!("Freed: {:.1} MB", freed_mb);
        println!("Status: {}", get_cleanup_status(&before, &after));
    }
}
