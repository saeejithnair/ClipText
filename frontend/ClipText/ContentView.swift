import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Text("ClipText v2")
                .font(.title)
            Text("Press Ctrl+Shift+9 to capture text from screen")
                .padding()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}