//
//  AboutView.swift
//  SereneScapes
//
//  Created by Cody Bromley on 1/1/25.
//  Converted to iOS by SereneScapes team.
//

import SwiftUI
import UIKit

struct AboutView: View {
  @ObservedObject private var creditsManager = SoundCreditsManager.shared
  @Environment(\.dismiss) private var dismiss
  @State private var isSoundCreditsExpanded = false
  @State private var isLicenseExpanded = false
  @State private var contributors: [String] = []
  @State private var translators: [String: [String]] = [:]

  private let appVersion =
    Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
  private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 20) {
          // App Icon
          if let iconName = Bundle.main.infoDictionary?["CFBundleIconName"] as? String,
            let uiImage = UIImage(named: iconName)
          {
            Image(uiImage: uiImage)
              .resizable()
              .frame(width: 100, height: 100)
              .cornerRadius(20)
          } else {
            Image(systemName: "waveform.circle.fill")
              .resizable()
              .frame(width: 100, height: 100)
              .foregroundColor(.accentColor)
          }

          // App Info Section
          VStack(spacing: 8) {
            Text("SereneScapes", comment: "App name")
              .font(.system(size: 24, weight: .medium, design: .rounded))

            Text(
              LocalizedStringKey("Version \(appVersion) (\(buildNumber))"),
              comment: "Version string"
            )
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          }

          // Links Section
          VStack(spacing: 12) {
            Link(destination: URL(string: "https://blankie.rest")!) {
              HStack(spacing: 4) {
                Image(systemName: "globe")
                Text("blankie.rest")
              }
            }

            Link(destination: URL(string: "https://github.com/codybrom/blankie")!) {
              HStack(spacing: 4) {
                Image(systemName: "star.fill")
                  .foregroundStyle(.yellow)
                Text("Star on GitHub", comment: "Star on GitHub label")
              }
            }

            Link(destination: URL(string: "https://github.com/codybrom/blankie/issues")!) {
              HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(.orange)
                Text("Report an Issue", comment: "Report an issue label")
              }
            }
          }
          .font(.system(size: 14))

          inspirationSection

          Divider()
            .padding(.horizontal, 40)

          // Developer Section
          developerSection

          // Contributor Section (when needed)
          if !contributors.isEmpty {
            Divider()
              .padding(.horizontal, 40)
            contributorSection
          }

          // Translator Section (if available)
          if !translators.isEmpty {
            Divider()
              .padding(.horizontal, 40)
            translatorSection
          }

          Divider()
            .padding(.horizontal, 40)

          Text("© 2025 ")
            .font(.caption)
            + Text(
              "Cody Bromley and contributors. All rights reserved.", comment: "Copyright notice"
            )
            .font(.caption)

          // Credits and License Section
          VStack(spacing: 12) {
            ExpandableSection(
              title: "Sound Credits",
              comment: "Expandable section title: Sound Credits",
              isExpanded: $isSoundCreditsExpanded,
              onExpand: {
                isLicenseExpanded = false
              }
            ) {
              VStack(alignment: .leading, spacing: 4) {
                ForEach(creditsManager.credits, id: \.name) { credit in
                  CreditRow(credit: credit)
                }
              }
            }

            ExpandableSection(
              title: "Software License",
              comment: "Expandable section title: Software License",
              isExpanded: $isLicenseExpanded,
              onExpand: {
                isSoundCreditsExpanded = false
              }
            ) {
              softwareLicenseSection
            }
          }
        }
        .padding(20)
      }
      .navigationTitle("About")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .onAppear {
      loadCredits()
    }
  }

  private var developerSection: some View {
    VStack(spacing: 4) {
      Text("Developed By", comment: "Developed by label")
        .font(.system(size: 13, weight: .bold))

      VStack(spacing: 8) {
        Text("Cody Bromley", comment: "Developer name")
          .font(.system(size: 13))

        HStack(spacing: 8) {
          Link(destination: URL(string: "https://www.codybrom.com")!) {
            Text("Website", comment: "Website link label")
          }
          .foregroundColor(.accentColor)

          Text("•")
            .foregroundStyle(.secondary)

          Link(destination: URL(string: "https://github.com/codybrom")!) {
            Text("GitHub", comment: "GitHub link label")
          }
          .foregroundColor(.accentColor)
        }
        .foregroundColor(.accentColor)
        .font(.system(size: 12))
      }
    }
    .frame(maxWidth: .infinity)
  }

  struct Credits: Codable {
    let contributors: [String]
    let translators: [String: [String]]
  }

  private func loadCredits() {
    guard let url = Bundle.main.url(forResource: "credits", withExtension: "json") else {
      print("Unable to find credits.json in bundle")
      return
    }

    do {
      let data = try Data(contentsOf: url)
      let decoder = JSONDecoder()
      let credits = try decoder.decode(Credits.self, from: data)
      self.contributors = credits.contributors
      self.translators = credits.translators
    } catch {
      print("Error loading credits: \(error)")
    }
  }

  private var contributorSection: some View {
    VStack(spacing: 8) {
      Text("Contributors", comment: "Contributors section title")
        .font(.system(size: 13, weight: .bold))
        .padding(.bottom, 4)

      HStack(spacing: 0) {
        ForEach(contributors.indices, id: \.self) { index in
          Text(contributors[index])
            .font(.system(size: 13))

          if index < contributors.count - 1 {
            Text(", ")
              .font(.system(size: 13))
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .frame(maxWidth: .infinity)
    .padding(.bottom, 4)
  }

  private var translatorSection: some View {
    VStack(spacing: 8) {
      Text("Translations", comment: "Translations section title")
        .font(.system(size: 13, weight: .bold))
        .padding(.bottom, 4)

      let translatedLanguages = translators.filter { !$0.value.isEmpty }.keys.sorted()
      let isOddCount = translatedLanguages.count % 2 != 0
      let gridLanguages = isOddCount ? Array(translatedLanguages.dropLast()) : translatedLanguages
      let lastLanguage = isOddCount ? translatedLanguages.last : nil

      VStack(spacing: 20) {
        if !gridLanguages.isEmpty {
          LazyVGrid(columns: [GridItem(.fixed(150)), GridItem(.fixed(150))], spacing: 20) {
            ForEach(gridLanguages, id: \.self) { language in
              if let translatorList = translators[language], !translatorList.isEmpty {
                VStack(spacing: 4) {
                  Text(language)
                    .font(.system(size: 12, weight: .medium))
                    .italic()
                    .foregroundStyle(.secondary)

                  Text(translatorList.joined(separator: ", "))
                    .font(.system(size: 13))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(width: 150, alignment: .center)
              }
            }
          }
          .frame(maxWidth: .infinity)
        }

        if let lastLanguage = lastLanguage,
          let translatorList = translators[lastLanguage], !translatorList.isEmpty
        {
          VStack(spacing: 4) {
            Text(lastLanguage)
              .font(.system(size: 12, weight: .medium))
              .italic()
              .foregroundStyle(.secondary)

            Text(translatorList.joined(separator: ", "))
              .font(.system(size: 13))
              .multilineTextAlignment(.center)
              .lineLimit(3)
              .fixedSize(horizontal: false, vertical: true)
          }
          .frame(width: 150, alignment: .center)
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.bottom, 4)
  }

  private var inspirationSection: some View {
    let projectURL = URL(string: "https://github.com/rafaelmardojai/blanket")!

    return Link(destination: projectURL) {
      Text(LocalizedStringKey("Inspired by Blanket by Rafael Mardojai CM"))
        .font(.system(size: 12))
        .italic()
        .tint(.accentColor)
    }
  }

  private var soundCreditsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Sound Credits", comment: "Sound credits section title")
        .font(.system(size: 13, weight: .bold))

      VStack(alignment: .leading, spacing: 4) {
        ForEach(creditsManager.credits, id: \.name) { credit in
          CreditRow(credit: credit)
        }
      }
    }
  }

  private var softwareLicenseSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(
        "This application comes with absolutely no warranty. This program is free software: you can redistribute it and/or modify it under the terms of the MIT License.",
        comment: "License and warranty explainer text"
      )
      .font(.system(size: 12))
      Text(
        "Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:",
        comment: "MIT License Section 1"
      )
      .font(.system(size: 12))
      Text(
        "The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.",
        comment: "MIT License Section 2"
      )
      .font(.system(size: 12))
      Text(
        "THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.",
        comment: "MIT License Section 3"
      )
      .font(.system(size: 12))
      Link(
        "Learn more about the MIT License",
        destination: URL(string: "https://opensource.org/licenses/MIT")!
      )
      .foregroundColor(.accentColor)
      .font(.system(size: 12))
    }
  }

  struct ExpandableSection<Content: View>: View {
    let title: String
    let comment: String
    @Binding var isExpanded: Bool
    let onExpand: () -> Void
    let content: Content

    init(
      title: String,
      comment: String,
      isExpanded: Binding<Bool>,
      onExpand: @escaping () -> Void,
      @ViewBuilder content: () -> Content
    ) {
      self.title = title
      self.comment = comment
      self._isExpanded = isExpanded
      self.onExpand = onExpand
      self.content = content()
    }

    var body: some View {
      VStack(spacing: 0) {
        Button(action: {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            if !isExpanded {
              onExpand()
            }
            isExpanded.toggle()
          }
        }) {
          HStack {
            Text(title)
              .font(.system(size: 13, weight: .bold))
            Spacer()
            Image(systemName: "chevron.right")
              .foregroundColor(.secondary)
              .imageScale(.small)
              .rotationEffect(.degrees(isExpanded ? 90 : 0))
              .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 12)
          .padding(.horizontal, 16)
          .background(Color(.secondarySystemBackground))
          .cornerRadius(10)
        }
        .buttonStyle(.plain)

        if isExpanded {
          content
            .padding(.top, 12)
            .padding(.horizontal, 16)
        }
      }
    }
  }

  struct CreditRow: View {
    let credit: SoundCredit

    var body: some View {
      VStack(alignment: .leading, spacing: 4) {
        soundNameView
        attributionView
      }
      .font(.system(size: 12))
      .padding(.vertical, 4)
    }

    private var soundNameView: some View {
      HStack(spacing: 4) {
        Text(credit.name)
          .fontWeight(.bold)

        Text(" — ")
          .foregroundStyle(.secondary)

        if let soundUrl = credit.soundUrl {
          Link(credit.soundName, destination: soundUrl)
            .foregroundColor(.accentColor)
        } else {
          Text(credit.soundName)
            .foregroundStyle(.secondary)
        }
      }
    }

    private var attributionView: some View {
      HStack(spacing: 4) {
        Text("By", comment: "Attribution by label")
          .foregroundStyle(.secondary)
        Text(credit.author)

        if let editor = credit.editor {
          Text("•").foregroundStyle(.secondary)
          Text("Edited by", comment: "Attribution edited by label")
            .foregroundStyle(.secondary)
          Text(editor)
        }

        if let licenseUrl = credit.license.url {
          Text("•").foregroundStyle(.secondary)
          Link(credit.license.linkText, destination: licenseUrl)
            .foregroundColor(.accentColor)
        }
      }
    }
  }
}

#Preview {
  AboutView()
}
