//
//  Struct+InternalProperties.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 06-10-16.
//  Copyright © 2016 Mathijs Kadijk. All rights reserved.
//

import Foundation

extension Struct {
  func addingInternalProperties(forBundleIdentifier bundleIdentifier: String, hostingBundle: String? = nil) -> Struct {
    let hostingBundleValue: String
    if let bundleName = hostingBundle, !bundleName.isEmpty {
      hostingBundleValue = "Bundle(for: R.Class.self).path(forResource: \"\(bundleName)\", ofType: \"bundle\").flatMap(Bundle.init(path:)) ?? Bundle(for: R.Class.self)"
    } else {
      hostingBundleValue = "Bundle(for: R.Class.self)"
    }

    let internalProperties = [
      Let(
        comments: [],
        accessModifier: .filePrivate,
        isStatic: true,
        name: "hostingBundle",
        typeDefinition: .inferred(Type._Bundle),
        value: hostingBundleValue),
      Let(
        comments: [],
        accessModifier: .filePrivate,
        isStatic: true,
        name: "applicationLocale",
        typeDefinition: .inferred(Type._Locale),
        value: "hostingBundle.preferredLocalizations.first.flatMap { Locale(identifier: $0) } ?? Locale.current")
    ]

    let internalClasses = [
      Class(accessModifier: .filePrivate, type: Type(module: .host, name: "Class"))
    ]

    let internalFunctions = [
      Function(
        availables: [],
        comments: ["Load string from Info.plist file"],
        accessModifier: .filePrivate,
        isStatic: true,
        name: "infoPlistString",
        generics: nil,
        parameters: [
          .init(name: "path", type: Type._Array.withGenericArgs([Type._String])),
          .init(name: "key", type: Type._String)
        ],
        doesThrow: false,
        returnType: Type._String.asOptional(),
        body: """
          var dict = hostingBundle.infoDictionary
          for step in path {
            guard let obj = dict?[step] as? [String: Any] else { return nil }
            dict = obj
          }
          return dict?[key] as? String
          """,
        os: []
      ),
      Function(
        availables: [],
        comments: ["Find the first language with a nonempty value for this key"],
        accessModifier: .internalLevel,
        isStatic: true,
        name: "localeBundle",
        generics: nil,
        parameters: [
          .init(name: "tableName", type: Type._String),
          .init(name: "key", type: Type._String),
          .init(name: "preferredLanguages", type: Type._Array.withGenericArgs([Type._String])),
          .init(name: "in", localName: "resourceBundle", type: Type._Bundle, defaultValue: "hostingBundle")
        ],
        doesThrow: false,
        returnType: Type._Tuple.withGenericArgs([Type._Locale, Type._Bundle]).asOptional(),
        body: """
          // Filter preferredLanguages to localizations, use first locale
          var languages = preferredLanguages
            .map { Locale(identifier: $0) }
            .prefix(1)
            .flatMap { locale -> [String] in
              if resourceBundle.localizations.contains(locale.identifier) {
                if let language = locale.languageCode, resourceBundle.localizations.contains(language) {
                  return [locale.identifier, language]
                } else {
                  return [locale.identifier]
                }
              } else if let language = locale.languageCode, resourceBundle.localizations.contains(language) {
                return [language]
              } else {
                return []
              }
            }

          // If there's no languages, use development language as backstop
          if languages.isEmpty {
            if let developmentLocalization = resourceBundle.developmentLocalization {
              languages = [developmentLocalization]
            }
          } else {
            // Insert Base as second item (between locale identifier and languageCode)
            languages.insert("Base", at: 1)

            // Add development language as backstop
            if let developmentLocalization = resourceBundle.developmentLocalization {
              languages.append(developmentLocalization)
            }
          }

          // A locale can have the table but lack this key. Try the next locale,
          // including the development language, before returning a raw key.
          let missingValue = UUID().uuidString
          for language in languages {
            if let lproj = resourceBundle.url(forResource: language, withExtension: "lproj"),
               let lbundle = Bundle(url: lproj)
            {
              let strings = lbundle.url(forResource: tableName, withExtension: "strings")
              let stringsdict = lbundle.url(forResource: tableName, withExtension: "stringsdict")

              if strings != nil || stringsdict != nil {
                let value = lbundle.localizedString(forKey: key, value: missingValue, table: tableName)
                // An empty plural format may be deliberate; an empty .strings
                // value is not a usable translation.
                if value != missingValue {
                  let hasPlural = value.isEmpty &&
                    stringsdict.flatMap { NSDictionary(contentsOf: $0)?[key] } != nil
                  if !value.isEmpty || hasPlural {
                    return (Locale(identifier: language), lbundle)
                  }
                }
              }
            }
          }

          // If the table is directly in the bundle, check the key there too.
          let strings = resourceBundle.url(forResource: tableName, withExtension: "strings", subdirectory: nil, localization: nil)
          let stringsdict = resourceBundle.url(forResource: tableName, withExtension: "stringsdict", subdirectory: nil, localization: nil)

          if strings != nil || stringsdict != nil {
            let value = resourceBundle.localizedString(forKey: key, value: missingValue, table: tableName)
            if value != missingValue {
              let hasPlural = value.isEmpty &&
                stringsdict.flatMap { NSDictionary(contentsOf: $0)?[key] } != nil
              if !value.isEmpty || hasPlural {
                return (applicationLocale, resourceBundle)
              }
            }
          }

          // If table is not found for requested languages, key will be shown
          return nil
          """,
        os: []
      )
    ]

    var externalStruct = self
    externalStruct.properties.append(contentsOf: internalProperties)
    externalStruct.functions.append(contentsOf: internalFunctions)
    externalStruct.classes.append(contentsOf: internalClasses)

    return externalStruct
  }
}
