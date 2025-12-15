import SwiftUI

// MARK: - Color Theme
struct GWColors {
    static let background = Color(hex: "0D0B1E")
    static let cardBackground = Color(hex: "1A1625")
    static let accent = Color(hex: "E53935") // Red accent
    static let accentSecondary = Color(hex: "7C4DFF") // Purple for buttons
    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "9E9E9E")
    static let divider = Color.white.opacity(0.1)
    static let success = Color(hex: "4CAF50")
    static let streakOrange = Color(hex: "FF9800")
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}

// MARK: - GoodWatch Logo (Red Reel)
struct GoodWatchLogo: View {
    var size: CGFloat = 28
    
    var body: some View {
        HStack(spacing: 8) {
            // Film reel icon in red
            ZStack {
                Circle()
                    .fill(GWColors.accent)
                    .frame(width: size, height: size)
                
                // Reel holes
                ForEach(0..<4) { i in
                    Circle()
                        .fill(GWColors.background)
                        .frame(width: size * 0.2, height: size * 0.2)
                        .offset(x: size * 0.25 * cos(Double(i) * .pi / 2),
                               y: size * 0.25 * sin(Double(i) * .pi / 2))
                }
                
                Circle()
                    .fill(GWColors.background)
                    .frame(width: size * 0.25, height: size * 0.25)
            }
            
            Text("GoodWatch")
                .font(.system(size: size * 0.7, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Story Circle
struct StoryCircle: View {
    let title: String
    let imageName: String
    let isNew: Bool
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: isNew ? [GWColors.accent, GWColors.accentSecondary] : [Color.gray.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 68, height: 68)
                
                AsyncImage(url: URL(string: imageName)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(GWColors.cardBackground)
                }
                .frame(width: 60, height: 60)
                .clipShape(Circle())
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(GWColors.textSecondary)
                .lineLimit(1)
        }
        .frame(width: 72)
    }
}

// MARK: - Mood Chip
struct MoodChip: View {
    let title: String
    let isSelected: Bool
    var onTap: () -> Void = {}
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : GWColors.textSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? GWColors.accentSecondary : GWColors.cardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.clear : GWColors.divider, lineWidth: 1)
                )
        }
    }
}

// MARK: - Movie Poster Card
struct MoviePosterCard: View {
    let title: String
    let year: String
    let posterURL: String
    var width: CGFloat = 110
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            AsyncImage(url: URL(string: posterURL)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(GWColors.cardBackground)
                    .overlay(
                        Image(systemName: "film")
                            .foregroundColor(GWColors.textSecondary)
                    )
            }
            .frame(width: width, height: width * 1.5)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(1)
            
            Text(year)
                .font(.caption2)
                .foregroundColor(GWColors.textSecondary)
        }
        .frame(width: width)
    }
}

// MARK: - Tonight's Pick Card
struct TonightsPickCard: View {
    let movie: Movie
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                AsyncImage(url: URL(string: movie.backdropURL ?? movie.posterURL)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: 200)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(GWColors.cardBackground)
                        .frame(width: geometry.size.width, height: 200)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                LinearGradient(
                    colors: [.clear, .black.opacity(0.8)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tonight's Pick")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(movie.year)
                        .font(.caption)
                        .foregroundColor(GWColors.textSecondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                        Text("Perfect for a suspenseful evening")
                            .font(.caption2)
                    }
                    .foregroundColor(GWColors.accentSecondary)
                }
                .padding()
            }
        }
        .frame(height: 200)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var showSeeAll: Bool = false
    var onSeeAll: () -> Void = {}
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Spacer()
            
            if showSeeAll {
                Button("See All") {
                    onSeeAll()
                }
                .font(.subheadline)
                .foregroundColor(GWColors.accentSecondary)
            }
        }
    }
}

// MARK: - Primary Button
struct GWButton: View {
    let title: String
    var style: ButtonStyle = .primary
    var action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary, outline
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(style == .outline ? GWColors.accentSecondary : .white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(style == .primary ? GWColors.accent : 
                              style == .secondary ? GWColors.accentSecondary : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(style == .outline ? GWColors.accentSecondary : Color.clear, lineWidth: 2)
                )
        }
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let title: String
    let isSelected: Bool
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(title)
                .font(.subheadline)
        }
        .foregroundColor(isSelected ? .white : GWColors.textSecondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isSelected ? GWColors.accentSecondary : GWColors.cardBackground)
        )
        .overlay(
            Capsule()
                .stroke(isSelected ? Color.clear : GWColors.divider, lineWidth: 1)
        )
    }
}

// MARK: - Stats Card
struct StatsCard: View {
    let value: String
    let label: String
    var icon: String? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(GWColors.accentSecondary)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(label)
                .font(.caption)
                .foregroundColor(GWColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(GWColors.cardBackground)
        )
    }
}

// MARK: - Taste Profile Bar
struct TasteProfileBar: View {
    let genre: String
    let percentage: Int
    
    var body: some View {
        HStack {
            Text(genre)
                .font(.subheadline)
                .foregroundColor(.white)
                .frame(width: 80, alignment: .leading)
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(GWColors.cardBackground)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(GWColors.accentSecondary)
                        .frame(width: geo.size.width * CGFloat(percentage) / 100)
                }
            }
            .frame(height: 8)
            
            Text("\(percentage)%")
                .font(.caption)
                .foregroundColor(GWColors.textSecondary)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Search Bar
struct GWSearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search movies, actors, lists..."
    var showCancel: Bool = false
    var onCancel: () -> Void = {}
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(GWColors.textSecondary)
                
                TextField(placeholder, text: $text)
                    .foregroundColor(.white)
                
                if !text.isEmpty {
                    Button(action: { text = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(GWColors.textSecondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(GWColors.cardBackground)
            )
            
            if showCancel {
                Button("Cancel") {
                    onCancel()
                }
                .foregroundColor(GWColors.accent)
            }
        }
    }
}

// MARK: - Achievement Badge
struct AchievementBadge: View {
    let title: String
    let isUnlocked: Bool
    var icon: String = "trophy.fill"
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isUnlocked ? GWColors.accentSecondary.opacity(0.2) : GWColors.cardBackground)
                    .frame(width: 60, height: 60)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isUnlocked ? GWColors.accentSecondary : GWColors.textSecondary)
            }
            
            Text(title)
                .font(.caption2)
                .foregroundColor(isUnlocked ? .white : GWColors.textSecondary)
                .multilineTextAlignment(.center)
            
            Text(isUnlocked ? "Unlocked" : "Locked")
                .font(.caption2)
                .foregroundColor(GWColors.textSecondary)
        }
        .frame(width: 80)
    }
}
