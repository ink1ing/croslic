import Foundation

enum ManualChecklistRenderer {
    static func render(report: ASTPlusReport, language: OutputLanguage) -> String {
        if language == .en {
            return """
            # AST-plus Manual Checklist

            - Generated At: \(report.generatedAt)
            - Machine: \(report.machineName)
            - Auto Status: `\(report.overallStatus)`

            ## Exterior

            - [ ] No obvious dents, deformation, or disassembly traces
            - [ ] Screws look normal and are not stripped or missing
            - [ ] Hinge feels normal with no abnormal sound

            ## Display

            - [ ] No obvious dead pixels on white/black/red/green/blue full-screen tests
            - [ ] No obvious backlight bleed, tint shift, or flicker
            - [ ] Low brightness and high refresh scenarios look normal

            ## Input And AV

            - [ ] All keys work
            - [ ] Trackpad works across the full area
            - [ ] Camera image looks normal
            - [ ] Speakers work on both channels
            - [ ] Microphone record/playback works

            ## Wireless And Ports

            - [ ] Wi-Fi actually connects
            - [ ] Bluetooth can connect to a real device
            - [ ] Every USB-C / Thunderbolt port detects a device
            - [ ] MagSafe or USB-C charging works

            ## Apple Diagnostics

            - [ ] Apple Diagnostics has been run
            - [ ] Diagnostic code has been recorded
            - [ ] Online/offline mode has been recorded
            - [ ] Extra notes are attached if any abnormal result exists
            """
        }

        return """
        # AST-plus 人工检查清单

        - 生成时间：\(report.generatedAt)
        - 机器名称：\(report.machineName)
        - 自动检测总体状态：`\(report.overallStatus)`

        ## 外观

        - [ ] 外壳无明显磕碰、变形、拆修痕迹
        - [ ] 螺丝状态正常，无明显拧花和缺失
        - [ ] 屏轴阻尼正常，开合无异响

        ## 显示屏

        - [ ] 纯白/纯黑/纯红/纯绿/纯蓝下无明显坏点
        - [ ] 无明显漏光、色偏、闪烁
        - [ ] 低亮度和高刷新率场景显示正常

        ## 输入与音视频

        - [ ] 键盘逐键测试正常
        - [ ] 触控板全区域移动与按压正常
        - [ ] 摄像头画面正常
        - [ ] 扬声器左右声道正常
        - [ ] 麦克风录音与回放正常

        ## 无线与端口

        - [ ] Wi-Fi 实际联网正常
        - [ ] 蓝牙可成功连接外设
        - [ ] 每个 USB-C / Thunderbolt 端口均可识别设备
        - [ ] MagSafe 或 USB-C 充电状态正常

        ## Apple Diagnostics

        - [ ] 已运行 Apple Diagnostics
        - [ ] 已记录诊断代码
        - [ ] 已记录联网/离线模式
        - [ ] 若有异常，已附上补充说明

        ## 备注

        - 诊断代码：
        - 人工复检结论：
        - 其他备注：
        """
    }
}
