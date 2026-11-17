import MowahCore
import SwiftUI

struct SettingsView: View {
    @Bindable var model: AppModel

    var body: some View {
        let texts = model.texts
        Form {
            if !model.hasPermission {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.yellow)
                        Text(texts("permission.explanation"))
                        Spacer()
                        Button(texts("permission.open")) { model.requestPermission() }
                    }
                }
            }

            Section(texts("group.activity")) {
                Picker(texts("field.method"), selection: $model.settings.method) {
                    Text(texts("method.invisible")).tag(Method.invisible)
                    Text(texts("method.visibleMove")).tag(Method.visibleMove)
                    Text(texts("method.key")).tag(Method.key)
                }
                LabeledContent(texts("field.circleSize")) {
                    NumberField(value: $model.settings.circleDiameter)
                    Text(texts("unit.pixels"))
                }
                // The circle size only means something for the visible movement.
                .disabled(model.settings.method != .visibleMove)
                LabeledContent(texts("field.idleFor")) {
                    NumberField(value: $model.settings.idleThresholdSecs)
                    Text(texts("unit.seconds"))
                }
                LabeledContent(texts("field.repeatEvery")) {
                    NumberField(value: $model.settings.intervalMinSecs)
                    Text(verbatim: "–")
                    NumberField(value: $model.settings.intervalMaxSecs)
                    Text(texts("unit.seconds"))
                }
                Toggle(texts("field.leftClick"), isOn: $model.settings.leftClick)
            }

            Section(texts("group.awake")) {
                Toggle(texts("field.preventSleep"), isOn: $model.settings.preventSleep)
                Toggle(texts("field.keepDisplayOn"), isOn: $model.settings.keepDisplayOn)
            }

            Section(texts("group.schedule")) {
                Toggle(isOn: $model.settings.scheduleEnabled) {
                    HStack {
                        Text(texts("field.schedule"))
                        TimeField(minuteOfDay: $model.settings.scheduleStartMinute)
                        Text(texts("field.scheduleAnd"))
                        TimeField(minuteOfDay: $model.settings.scheduleEndMinute)
                    }
                }
            }

            Section {
                Toggle(texts("field.launchAtLogin"), isOn: $model.launchAtLogin)
                Picker(texts("field.language"), selection: $model.settings.language) {
                    Text(texts("language.system")).tag(LanguageChoice.system)
                    // A language's own name is the same whatever language is in use.
                    Text(verbatim: "Svenska").tag(LanguageChoice.swedish)
                    Text(verbatim: "English").tag(LanguageChoice.english)
                }
            } header: {
                Text(texts("group.general"))
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
        return model.texts.format("app.footer", version, year)
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
