import SwiftUI

struct CommandSheet: View {
    @ObservedObject var state: DeckState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedApp: InstalledApp?
    @State private var arguments = ""
    @State private var name = ""
    @State private var errorText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("添加命令按钮").font(.headline)
                Spacer()
                Button("关闭") { dismiss() }
            }
            Text("执行所选应用内置的命令行（参数只保存在本机；手机端只发送按钮 ID）")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("应用", selection: $selectedApp) {
                Text("请选择").tag(InstalledApp?.none)
                ForEach(state.installedApps) { app in
                    Text(app.name).tag(InstalledApp?.some(app))
                }
            }
            .frame(maxWidth: 420)

            HStack {
                Text("参数")
                TextField("例如：snip", text: $arguments)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Text("名称")
                TextField("按钮显示名，例如：截图", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            Text(errorText).font(.caption).foregroundStyle(.red).frame(height: 14)

            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("创建") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedApp == nil)
            }
        }
        .padding(16)
        .frame(width: 520)
        .onAppear {
            if state.installedApps.isEmpty { state.installedApps = AppEnumerator.installedApps() }
        }
    }

    private func save() {
        guard let app = selectedApp else { return }
        let args = arguments.split(separator: " ").map(String.init)
        state.addCommand(name: name.isEmpty ? app.name : name,
                         appPath: app.path,
                         bundleID: app.bundleID,
                         arguments: args)
        dismiss()
    }
}
