import Foundation

let titles = [
    "Savory Tofu Scramble with Avocado Toast",
    "Mediterranean Chickpea & Spinach Stew",
    "Vegan Almond Butter & Berry French Toast",
    "Tempeh and Avocado Wrap",
    "High-Calorie Peanut Butter Banana Oatmeal"
]

let group = DispatchGroup()
var codes: [Int] = []

for title in titles {
    group.enter()
    let prompt = "A delicious beautiful high quality food photography of \(title)"
    let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
    let sig = abs(title.lowercased().hashValue % 9999) + 1
    let urlString = "https://image.pollinations.ai/prompt/\(encoded)?width=800&height=500&nologo=true&seed=\(sig)"
    
    let task = URLSession.shared.dataTask(with: URL(string: urlString)!) { data, response, error in
        if let res = response as? HTTPURLResponse {
            codes.append(res.statusCode)
        }
        group.leave()
    }
    task.resume()
}

group.wait()
print("Status codes: \(codes)")
