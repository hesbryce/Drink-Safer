//
//  ContentView.swift
//  Drink Safer
//
//  Created by Bryce Ellis on 9/21/24.
//

import SwiftUI
import SwiftData


// User Model to store user data
struct User {
    var weight: Double // in lbs
    var age: Int
    var sex: Sex
    var metabolismRate: Double // BAC decrease per hour, default 0.015
    var alcoholDistributionRatio: Double {
        return sex == .male ? 0.73 : 0.66
    }
    
    enum Sex {
        case male, female
    }
    
    init(weight: Double, age: Int, sex: Sex, metabolismRate: Double = 0.015) {
        self.weight = weight
        self.age = age
        self.sex = sex
        self.metabolismRate = metabolismRate
    }
}

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager.shared

    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    
    @State private var showingAddDrinkSheet = false
    @State private var user = User(weight: 75, age: 25, sex: .male)
    
    // Calculated BAC
    private var bac: Double {
        calculateBAC(for: user, with: items)
    }

    var body: some View {
        NavigationView {
            VStack {
                // Intoxication Gauge
                Text("Current BAC: \(bac, specifier: "%.3f")")
                    .font(.title)
                    .padding()
                
                ProgressBar(value: bac, maxValue: 0.3)
                    .frame(height: 20)
                    .padding()
                
                GuidanceMessage(bac: bac)
                    .padding()
                
                List {
                    ForEach(items) { item in
                        VStack(alignment: .leading) {
                            Text(item.drinkType)
                            Text("\(item.volume, specifier: "%.1f") oz - \(item.alcoholContent, specifier: "%.1f")% ABV")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                    ToolbarItem {
                        Button(action: { showingAddDrinkSheet.toggle() }) {
                            Label("Add Drink", systemImage: "plus")
                        }
                    }
                }
            }
            .navigationTitle("Intoxication Gauge")
            .sheet(isPresented: $showingAddDrinkSheet) {
                AddDrinkView { newDrink in
                    addDrink(drink: newDrink)
                }
            }
        } .onAppear {
            healthKitManager.requestAuthorization()
        }
    }

    // Function to calculate BAC using user data and drink logs
    private func calculateBAC(for user: User, with items: [Item]) -> Double {
        // Calculate total alcohol consumed in grams
        let totalAlcoholInGrams = items.reduce(0.0) { result, item in
            let alcoholVolumeInLiters = (item.volume * 29.5735) / 1000.0 // Convert oz to liters
            let alcoholInGrams = alcoholVolumeInLiters * 789 * (item.alcoholContent / 100.0) // Calculate pure alcohol in grams
            return result + alcoholInGrams
        }

        // Calculate body water in grams using user's weight in kilograms
        // The factor of 1000 is to convert kg to grams directly
        let bodyWaterInGrams = user.weight * user.alcoholDistributionRatio * 1000.0 // Directly use kg without converting from lbs
        
        // Calculate BAC
        let bac = totalAlcoholInGrams / bodyWaterInGrams
        
        return bac * 100 // Convert to percentage
    }


    private func addDrink(drink: Drink) {
        withAnimation {
            let newItem = Item(
                timestamp: Date(),
                drinkType: drink.type,
                volume: drink.volume,
                alcoholContent: drink.alcoholContent
            )
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

// ProgressBar view for BAC visual indicator
struct ProgressBar: View {
    var value: Double
    var maxValue: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.3)
                    .foregroundColor(Color.gray)
                
                Rectangle()
                    .frame(width: min(CGFloat(self.value) / CGFloat(self.maxValue) * geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(self.value < 0.08 ? Color.green : self.value < 0.15 ? Color.yellow : Color.red)
                    .animation(.linear, value: value)
            }
            .cornerRadius(45.0)
        }
    }
}

// Guidance Message based on BAC
struct GuidanceMessage: View {
    var bac: Double
    
    var body: some View {
        if bac < 0.03 {
            Text("You are safe to drive.")
                .foregroundColor(.green)
                .font(.headline)
        } else if bac < 0.08 {
            Text("Be cautious. Limit your intake.")
                .foregroundColor(.yellow)
                .font(.headline)
        } else {
            Text("Do not drive. Consider slowing down your intake.")
                .foregroundColor(.red)
                .font(.headline)
        }
    }
}

struct AddDrinkView: View {
    @Environment(\.dismiss) var dismiss

    @State private var selectedDrinkType = "Beer"
    @State private var volume: Double = 12 // Default volume in oz
    @State private var alcoholContent: Double = 5.0 // Default ABV for beer

    var onSave: (Drink) -> Void

    var body: some View {
        NavigationView {
            Form {
                Picker("Drink Type", selection: $selectedDrinkType) {
                    Text("Beer").tag("Beer")
                    Text("Wine").tag("Wine")
                    Text("Spirits").tag("Spirits")
                }
                
                HStack {
                    Text("Volume (oz)") // Updated label
                    Spacer()
                    TextField("Volume", value: $volume, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Alcohol Content (%)")
                    Spacer()
                    TextField("ABV", value: $alcoholContent, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            .navigationTitle("Add Drink")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newDrink = Drink(type: selectedDrinkType, volume: volume, alcoholContent: alcoholContent)
                        onSave(newDrink)
                        dismiss()
                    }
                }
            }
        }
    }
}

// Helper struct to define a drink
struct Drink {
    var type: String
    var volume: Double
    var alcoholContent: Double
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
