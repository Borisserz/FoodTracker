import Foundation

let titles = [
    "Savory Tofu Scramble with Avocado Toast",
    "Mediterranean Chickpea & Spinach Stew",
    "Vegan Almond Butter & Berry French Toast",
    "Tempeh and Avocado Wrap",
    "High-Calorie Peanut Butter Banana Oatmeal"
]

var codes: [Int] = []
let semaphore = DispatchSemaphore(value: 0)

Task {
    for title in titles {
        let prompt = "A delicious beautiful high quality food photography of \(title)"
        let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        let urlString = "https://image.pollinations.ai/prompt/\(encoded)?width=800&height=500&nologo=true&seed=1"
        
        do {
            let (_, response) = try await URLSession.shared.data(from: URL(string: urlString)!)
            if let res = response as? HTTPURLResponse {
                codes.append(res.statusCode)
            }
        } catch {
            print(error)
        }
        
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
    semaphore.signal()
}

semaphore.wait()
print("Status codes with 500ms delay: \(codes)")
