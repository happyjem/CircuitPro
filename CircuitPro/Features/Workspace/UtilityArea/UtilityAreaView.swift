//
//  UtilityAreaView.swift
//  CircuitPro
//
//  Created by Giorgi Tchelidze on 30.05.25.
//

import SwiftUI
import SwiftData

enum UtilityAreaTab: Displayable {

    case design
    case appLibrary
    case userLibrary

    var label: String {
        switch self {
        case .design:
            return "Design Library"
        case .appLibrary:
            return "App Library"
        case .userLibrary:
            return "User Library"
        }
    }

    var icon: String {
        switch self {
        case .design:
            return CircuitProSymbols.Design.design.replacingOccurrences(of: ".fill", with: "")
        case .appLibrary:
            return "books.vertical"
        case .userLibrary:
            return "person"
        }
    }
}

enum ComponentCategoryFilter: Identifiable, Hashable {
    case all
    case category(ComponentCategory)

    var id: String {
        switch self {
        case .all:
            return "all"
        case .category(let category):
            return category.rawValue
        }
    }

    var label: String {
        switch self {
        case .all:
            return "All"
        case .category(let category):
            return category.label
        }
    }
}

struct UtilityAreaView: View {

    @Environment(\.projectManager)
    private var projectManager
    
    @Environment(\.modelContext)
    private var modelContext

    @Query(
        filter: #Predicate<Component> { component in
            // Dynamic filtering will be handled through a computed property
            true
        },
        sort: [SortDescriptor(\.name, order: .forward)]
    )
    private var components: [Component]

    @State private var selectedCategory: ComponentCategoryFilter = .all
    @State private var selectedTab: UtilityAreaTab = .design

    var filteredComponents: [Component] {
        switch selectedCategory {
        case .all:
            return components
        case .category(let category):
            return components.filter { $0.category == category }
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            utilityAreaTab

            Divider()
                .foregroundStyle(.quaternary)

            selectionView
            .frame(width: 240)

            Divider()
                .foregroundStyle(.quaternary)
            contentView
            .frame(maxWidth: .infinity)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var selectionView: some View {
        Group {
            switch selectedTab {
            case .design:
                EmptyView()
            case .appLibrary:
                List(
                    [ComponentCategoryFilter.all] + ComponentCategory.allCases.map { .category($0) },
                    id: \.self,
                    selection: $selectedCategory
                ) { filter in
                    HStack(spacing: 5) {
                        Image(systemName: "text.page")
                            .foregroundStyle(selectedCategory == filter ? .primary : .secondary)
                        Text(filter.label)
                    }
                    .listRowSeparator(.hidden)
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
            case .userLibrary:
                Text("User library")
            }
        }
    }

    private var utilityAreaTab: some View {
        VStack(spacing: 12.5) {
            ForEach(UtilityAreaTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    Image(systemName: tab == selectedTab ? "\(tab.icon).fill" : tab.icon)
                        .font(.system(size: 12.5))
                        .foregroundStyle(selectedTab == tab ? .blue : .secondary)
                        .if(tab == .design) { view in
                            view.padding(.top, 12.5)
                        }
                }
                .buttonStyle(.plain)
                .help(tab.label)

            }
            Spacer()
        }
        .frame(width: 40)
    }

    private var contentView: some View {
        Group {
            switch selectedTab {
            case .design:
                ScrollView {
                    VStack {
                        ForEach(projectManager.designComponents) { designComponent in
                            Text(designComponent.definition.name)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            case .appLibrary:
                ComponentGridView(filteredComponents) { component in
                    ComponentCardView(component: component)
                        .contextMenu {
                            Button("Delete Component") {
                                modelContext.delete(component)
                            }
                        }
                }
                .contentMargins([.top, .leading, .bottom], 10, for: .scrollContent)
            case .userLibrary:
                Text("User library")
            }
        }
    }
}
