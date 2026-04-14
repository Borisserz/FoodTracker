//
//  HoloAchievementCard.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 14.04.26.
//

//
//  HoloAchievementCard.swift
//  FoodTracker
//

import SwiftUI

struct HoloAchievementCard: View {
    let achievement: Achievement
    let isUnlocked: Bool
    let minX: CGFloat
    let screenWidth: CGFloat
    
    @State private var isPressed = false
    
    // МАТЕМАТИКА 3D ЭФФЕКТА И БЛИКА
    private var offset: CGFloat {
        // Находим центр карточки относительно глобального экрана
        let cardMidX = minX + 60 // 120 (ширина) / 2
        return cardMidX - screenWidth / 2
    }
    
    private var rotationAngle: Double {
        // Рассчитываем угол наклона (максимум 20 градусов)
        let angle = (offset / (screenWidth / 2)) * 20
        return max(-20, min(20, angle))
    }
    
    var body: some View {
        ZStack {
            if isUnlocked {
                // MARK: - UNLOCKED STATE (Holo Card)
                ZStack {
                    // Базовый цветной градиент
                    LinearGradient(
                        colors: [achievement.color.opacity(0.6), achievement.color],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Содержимое
                    VStack(spacing: 12) {
                        Image(systemName: achievement.icon)
                            .font(.system(size: 38))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                        
                        VStack(spacing: 6) {
                            Text(achievement.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                            
                            Text(achievement.description)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                                .lineLimit(3)
                        }
                    }
                    .padding(12)
                    
                    // Голографический блик (смещается в зависимости от скролла)
                    LinearGradient(
                        colors: [.clear, .white.opacity(0.6), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: 250)
                    .offset(x: -offset * 0.8) // Блик движется в противовес наклону
                    .blendMode(.plusLighter)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                // Эффект свечения (Outer Glow)
                .shadow(color: achievement.color.opacity(0.5), radius: 10, y: 5)
                
            } else {
                // MARK: - LOCKED STATE (Frosted Glass)
                ZStack {
                    Color.gray.opacity(0.15)
                    
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    VStack(spacing: 12) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.gray.opacity(0.5))
                            .shadow(color: .white.opacity(0.2), radius: 1, y: 1)
                        
                        VStack(spacing: 6) {
                            Text(achievement.title)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundColor(.primary.opacity(0.5))
                            
                            Text(achievement.description)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                    }
                    .padding(12)
                }
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                .opacity(0.8)
            }
        }
        .frame(width: 120, height: 160)
        // Применение 3D трансформации
        .rotation3DEffect(
            .degrees(rotationAngle),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.5 // Придает глубину
        )
        .scaleEffect(isPressed ? 0.95 : 1.0)
        // Микроинтеракция при нажатии
        .onTapGesture {
            // Разный тактильный отклик в зависимости от статуса
            HapticManager.shared.impact(style: isUnlocked ? .heavy : .rigid)
            
            // Пружинная анимация сжатия
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            // Возврат в исходное состояние
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }
    }
}
