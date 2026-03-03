//
//  Double+Extensions.swift
//
//  Number formatting extensions
//

import Foundation

extension Double {
    var currencyString: String {
        String(format: "$%.2f", self)
    }
    
    var percentageString: String {
        String(format: "%.0f%%", self)
    }
    
    var wholeNumberString: String {
        String(format: "%.0f", self)
    }
}
