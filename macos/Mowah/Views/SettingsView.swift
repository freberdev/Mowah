import MowahCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        Form {
            if !model.hasPermission {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text("permission.explanation")
                        Spacer()
                        Button("permission.open") { model.requestPermission() }
                    }
                }
            }

            Section("group.activity") {
                Picker("field.method", selection: $model.settings.method) {
                    Text("method.invisible").tag(Method.invisible)
                    Text("method.visibleMove").tag(Method.visibleMove)
                    Text("method.key").tag(Method.key)
                }
                LabeledContent("field.circleSize") {
                    NumberField(value: $model.settings.circleDiameter)
                    Text("unit.pixels")
                }
                // The circle size only means something for the visible movement.
                .disabled(model.settings.method != .visibleMove)
                LabeledContent("field.idleFor") {
                    NumberField(value: $model.settings.idleThresholdSecs)
                    Text("unit.seconds")
                }
                LabeledContent("field.repeatEvery") {
                    NumberField(value: $model.settings.intervalMinSecs)
                    Text(verbatim: "–")
                    NumberField(value: $model.settings.intervalMaxSecs)
                    Text("unit.seconds")
                }
                Toggle("field.leftClick", isOn: $model.settings.leftClick)
            }

            Section("group.awake") {
                Toggle("field.preventSleep", isOn: $model.settings.preventSleep)
                Toggle("field.keepDisplayOn", isOn: $model.settings.keepDisplayOn)
            }

            Section {
                Toggle(isOn: $model.settings.scheduleEnabled) {
                    HStack {
                        Text("field.schedule")
                        TimeField(minuteOfDay: $model.settings.scheduleStartMinute)
                        Text("field.scheduleAnd")
                        TimeField(minuteOfDay: $model.settings.scheduleEndMinute)
                    }
                }
                Toggle("field.launchAtLogin", isOn: $model.launchAtLogin)
            } header: {
                Text("group.scheduleAndStart")
            } footer: {
                Text(footer)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var footer: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? ""
        let year = info?["MowahBuildYear"] as? String ?? ""
        return String(format: String(localized: "app.footer"), version, year)
    }
}

/// A field for a whole number. The value is taken when the field is left or
/// Return is pressed, not while typing, and anything that is not a whole number
/// puts the previous value back. The model corrects values outside the limits.
private struct NumberField: View {
    @Binding var value: Int
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .labelsHidden()
            // In a grouped form a text field is drawn without a frame, and then it
            // does not look like something that can be typed in.
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.trailing)
            .frame(width: 56)
            .focused($focused)
            .onAppear { text = String(value) }
            .onChange(of: value) { _, newValue in text = String(newValue) }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            .onSubmit(commit)
    }

    private func commit() {
        if let number = parseWholeNumber(text) {
            value = number
        }
        text = String(value)
    }
}

/// A field for a time of day, written as 08:00.
private struct TimeField: View {
    @Binding var minuteOfDay: Int
    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("", text: $text)
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.center)
            .frame(width: 56)
            .focused($focused)
            .onAppear { text = formatTime(minuteOfDay) }
            .onChange(of: minuteOfDay) { _, newValue in text = formatTime(newValue) }
            .onChange(of: focused) { _, isFocused in
                if !isFocused { commit() }
            }
            .onSubmit(commit)
    }

    private func commit() {
        if let minute = parseTime(text) {
            minuteOfDay = minute
        }
        text = formatTime(minuteOfDay)
    }
}
