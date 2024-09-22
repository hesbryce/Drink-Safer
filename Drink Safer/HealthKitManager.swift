//
//  HealthKitManager.swift
//  Drink Safer
//
//  Created by Bryce Ellis on 9/21/24.
//

import HealthKit
import Combine

class HealthKitManager: ObservableObject {
    static let shared = HealthKitManager()
    
    private let healthStore = HKHealthStore()
    
    // Published properties to update UI in SwiftUI
    @Published var isAuthorized: Bool = false
    @Published var userWeight: Double? // in kg
    @Published var userAlcoholIntake: [HKQuantitySample] = []
    @Published var userSex: HKBiologicalSex?
    @Published var userAge: Int?
    
    private var cancellables = Set<AnyCancellable>()
    
    private var readTypes: Set<HKObjectType> {
        return [
            HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages)!, // Read Alcoholic drinks
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)!, // Read Sex
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth)!, // Read Age
            HKObjectType.quantityType(forIdentifier: .bodyMass)! // Read Weight
        ]
    }
    
    private var writeTypes: Set<HKSampleType> {
        return [
            HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages)!, // Write Alcoholic drinks
            HKObjectType.quantityType(forIdentifier: .bodyMass)! // Write Weight
        ]
    }
    
    // Request authorization to read and write HealthKit data
    func requestAuthorization() {
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if success {
                    self.loadUserData()
                } else if let error = error {
                    print("HealthKit Authorization Failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Load user data once authorized
    private func loadUserData() {
        getBiologicalSex()
        getAge()
        readMostRecentWeight()
        readAlcoholicDrinks()
    }
    
    // Read user's biological sex
    func getBiologicalSex() {
        do {
            let sex = try healthStore.biologicalSex().biologicalSex
            DispatchQueue.main.async {
                self.userSex = sex
            }
        } catch {
            print("Failed to read biological sex: \(error)")
        }
    }
    
    // Read user's date of birth and calculate age
    func getAge() {
        do {
            let birthDateComponents = try healthStore.dateOfBirthComponents()
            guard let birthYear = birthDateComponents.year,
                  let birthMonth = birthDateComponents.month,
                  let birthDay = birthDateComponents.day else {
                print("Failed to get complete date of birth components")
                return
            }

            // Convert DateComponents to a Date object
            let calendar = Calendar.current
            let birthDate = calendar.date(from: DateComponents(year: birthYear, month: birthMonth, day: birthDay)) ?? Date()
            let now = Date()
            let ageComponents = calendar.dateComponents([.year], from: birthDate, to: now)
            
            DispatchQueue.main.async {
                self.userAge = ageComponents.year
            }
        } catch {
            print("Failed to read age: \(error)")
        }
    }
    
    // Read the most recent weight entry
    func readMostRecentWeight() {
        // Ensure the weight type is for body mass
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }

        // Create a sort descriptor to get the most recent weight sample
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        // Define the query to get the most recent weight sample
        let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, results, error in
            guard let results = results, let sample = results.first as? HKQuantitySample else {
                print("Failed to fetch weight: \(error?.localizedDescription ?? "No data")")
                return
            }

            // Retrieve the weight in pounds directly
            let weightInLbs = sample.quantity.doubleValue(for: .pound()) // Use .pound() unit

            // Update the userWeight property on the main thread
            DispatchQueue.main.async {
                self.userWeight = weightInLbs
            }
        }
        
        // Execute the query
        healthStore.execute(query)
    }

    // Read logged alcoholic drinks
    func readAlcoholicDrinks() {
        guard let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else { return }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: alcoholType, predicate: nil, limit: 0, sortDescriptors: [sortDescriptor]) { _, results, error in
            guard let results = results as? [HKQuantitySample], error == nil else {
                print("Failed to fetch alcoholic drinks: \(error?.localizedDescription ?? "No data")")
                return
            }
            
            DispatchQueue.main.async {
                self.userAlcoholIntake = results
            }
        }
        healthStore.execute(query)
    }
    
    // Log a new alcoholic drink
    func logAlcoholicDrink(amountInGrams: Double, date: Date = Date()) {
        guard let alcoholType = HKObjectType.quantityType(forIdentifier: .numberOfAlcoholicBeverages) else { return }
        
        let quantity = HKQuantity(unit: .gram(), doubleValue: amountInGrams)
        let sample = HKQuantitySample(type: alcoholType, quantity: quantity, start: date, end: date)
        
        healthStore.save(sample) { success, error in
            if success {
                print("Successfully logged alcoholic drink.")
                self.readAlcoholicDrinks() // Refresh the data
            } else if let error = error {
                print("Failed to log alcoholic drink: \(error.localizedDescription)")
            }
        }
    }
    
    // Update user's weight
    func logWeight(weightInKg: Double, date: Date = Date()) {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass) else { return }
        
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: weightInKg)
        let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)
        
        healthStore.save(sample) { success, error in
            if success {
                print("Successfully logged weight.")
                self.readMostRecentWeight() // Refresh the data
            } else if let error = error {
                print("Failed to log weight: \(error.localizedDescription)")
            }
        }
    }
}
