import Foundation
import SwiftUI

/// Maps bundled food cover asset identifiers and legacy Unsplash URLs to local Assets.xcassets names.
enum FoodCoverAssets {
    private static let photoIDToAssetName: [String: String] = [
        "photo-1498837167922-ddd27525d352": "food_cover_1498837167922_ddd27525d352",
        "photo-1504674900247-0877df9cc836": "food_cover_1504674900247_0877df9cc836",
        "photo-1505253716362-afaea1d3d1af": "food_cover_1505253716362_afaea1d3d1af",
        "photo-1511690656952-34342bb7c2f2": "food_cover_1511690656952_34342bb7c2f2",
        "photo-1512621776951-a57141f2eefd": "food_cover_1512621776951_a57141f2eefd",
        "photo-1519708227418-c8fd9a32b7a2": "food_cover_1519708227418_c8fd9a32b7a2",
        "photo-1525351484163-7529414344d8": "food_cover_1525351484163_7529414344d8",
        "photo-1528207776546-365bb710ee93": "food_cover_1528207776546_365bb710ee93",
        "photo-1532550907401-a500c9a57435": "food_cover_1532550907401_a500c9a57435",
        "photo-1543339308-43e59d6b73a6": "food_cover_1543339308_43e59d6b73a6",
        "photo-1544025162-d76694265947": "food_cover_1544025162_d76694265947",
        "photo-1546039907-7fa05f864c02": "food_cover_1546039907_7fa05f864c02",
        "photo-1546069901-ba9599a7e63c": "food_cover_1546069901_ba9599a7e63c",
        "photo-1550304943-4f24f54ddde9": "food_cover_1550304943_4f24f54ddde9",
        "photo-1552566626-52f8b828add9": "food_cover_1552566626_52f8b828add9",
        "photo-1556881286-fc6915169721": "food_cover_1556881286_fc6915169721",
        "photo-1564834724105-918b73d1b9e0": "food_cover_1564834724105_918b73d1b9e0",
        "photo-1582169505937-b9992bd01ed9": "food_cover_1582169505937_b9992bd01ed9",
        "photo-1604908176997-125f25cc6f3d": "food_cover_1604908176997_125f25cc6f3d",
        "photo-1610832958506-aa56368176cf": "food_cover_1610832958506_aa56368176cf"
    ]

    private static let allBundledAssetNames: Set<String> = Set(photoIDToAssetName.values)

    static func assetName(for rawString: String) -> String? {
        let trimmed = rawString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if allBundledAssetNames.contains(trimmed) {
            return trimmed
        }
        for (photoID, assetName) in photoIDToAssetName where trimmed.contains(photoID) {
            return assetName
        }
        return nil
    }
}
