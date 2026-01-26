#!/usr/bin/env python3
"""
Test script for difficulty calculator
Tests the hiking difficulty formula with various route scenarios
"""

from services.difficulty_calculator import calculate_difficulty, get_difficulty_score

def test_difficulty_calculator():
    """Run tests for difficulty calculator"""
    print("=" * 70)
    print("PRUEBA DEL CÁLCULO DE DIFICULTAD DE RUTAS DE SENDERISMO")
    print("=" * 70)
    print()

    test_cases = [
        # (distance_km, elevation_gain, estimated_time, expected_difficulty, description)
        (3, 50, "1:00", "Fácil", "Ruta muy corta, sin casi desnivel"),
        (5, 100, "1:30", "Moderada", "Ruta corta con desnivel (score ~7.3)"),
        (8, 200, "2:30", "Moderada", "Ruta media con desnivel moderado"),
        (10, 300, "3:30", "Moderada", "Ruta media-larga"),
        (15, 600, "4:00", "Difícil", "Ruta larga con mucho desnivel"),
        (20, 800, "5:30", "Muy Difícil", "Ruta muy larga con desnivel importante"),
        (25, 1200, "7:00", "Muy Difícil", "Ruta extenuante con mucho desnivel"),
        (30, 1500, "8:00", "Muy Difícil", "Ruta para expertos"),
        (0, 0, None, "Fácil", "Ruta de prueba (vacía)"),
        (2, 10, None, "Fácil", "Ruta sin tiempo estimado"),
    ]

    print(f"{'Dist(km)':<12} {'Desnivel(m)':<15} {'Tiempo':<12} {'Score':<10} {'Dificultad':<15} {'Descripción'}")
    print("-" * 100)

    all_passed = True
    for distance_km, elevation_gain, estimated_time, expected, description in test_cases:
        difficulty = calculate_difficulty(distance_km, elevation_gain, estimated_time)
        score = get_difficulty_score(distance_km, elevation_gain)
        
        passed = difficulty == expected
        all_passed = all_passed and passed
        
        status = "✓" if passed else "✗"
        
        time_str = estimated_time if estimated_time else "N/A"
        print(f"{distance_km:<12.1f} {elevation_gain:<15} {time_str:<12} {score:<10.2f} {difficulty:<15} {description}")
        
        if not passed:
            print(f"  ⚠️  ESPERADO: {expected}, OBTENIDO: {difficulty}")

    print()
    print("=" * 70)
    if all_passed:
        print("✓ TODAS LAS PRUEBAS PASARON")
    else:
        print("✗ ALGUNAS PRUEBAS FALLARON")
    print("=" * 70)
    print()
    
    # Mostrar escala de dificultad
    print("ESCALA DE DIFICULTAD:")
    print("  Fácil:       Score < 7")
    print("  Moderada:    7 <= Score < 17")
    print("  Difícil:     17 <= Score < 27")
    print("  Muy Difícil: Score >= 27")
    print()
    
    # Fórmula
    print("FÓRMULA UTILIZADA:")
    print("  Score = distancia_km * 1.2 + (desnivel_m / 80)")
    print()
    print("PARÁMETROS CONSIDERADOS:")
    print("  - Distancia en kilómetros")
    print("  - Ganancia de elevación en metros")
    print("  - Tiempo estimado (para validación)")
    print()


if __name__ == "__main__":
    test_difficulty_calculator()
