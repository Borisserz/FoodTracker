import Foundation

let title = "Vegan Almond Butter & Berry French Toast"
let prompt = "A delicious beautiful high quality food photography of \(title)"
let encoded = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
let urlString = "https://image.pollinations.ai/prompt/\(encoded)?width=800&height=500&nologo=true&seed=1"
print(urlString)
if URL(string: urlString) == nil {
    print("URL IS NIL")
} else {
    print("URL IS VALID")
}
