#!/usr/bin/env python3
"""
Migration script to update existing routes with calculated difficulty.
This script validates and recalculates difficulty for routes as needed.
"""

import sys
from db import get_connection
from services.difficulty_calculator import calculate_difficulty

def update_route_difficulties():
    """Update difficulty for all routes with empty or invalid difficulty values"""
    
    conn = get_connection()
    cur = conn.cursor()
    
    print("=" * 70)
    print("ACTUALIZACIÓN DE DIFICULTAD DE RUTAS")
    print("=" * 70)
    print()
    
    # Fetch ALL routes
    cur.execute("""
        SELECT route_id, name, distance_km, elevation_gain, estimated_time, difficulty
        FROM routes
        ORDER BY route_id ASC
    """)
    
    routes = cur.fetchall()
    
    if not routes:
        print("✓ No hay rutas para procesar.")
        cur.close()
        conn.close()
        return
    
    print(f"Se encontraron {len(routes)} ruta(s) para procesar.")
    print()
    
    valid_difficulties = {'Fàcil', 'Mitjana', 'Difícil', 'Molt Difícil', 
                         'Fácil', 'Moderada', 'Muy Difícil'}
    
    updated_count = 0
    for route_id, name, distance_km, elevation_gain, estimated_time, current_difficulty in routes:
        # Check if current difficulty is valid
        current_is_valid = current_difficulty in valid_difficulties if current_difficulty else False
        
        if current_is_valid:
            print(f"[{route_id}] {name}")
            print(f"  ✓ Dificultad existente válida: {current_difficulty}")
            print()
            continue
        
        # Calculate difficulty in Catalan to match existing data
        difficulty = calculate_difficulty(
            float(distance_km or 0),
            int(elevation_gain or 0),
            estimated_time,
            lang='ca'  # Use Catalan to match existing data
        )
        
        print(f"[{route_id}] {name}")
        print(f"  Distancia: {distance_km} km, Elevación: {elevation_gain} m")
        print(f"  Dificultad calculada: {difficulty}")
        
        # Update the route
        try:
            cur.execute("""
                UPDATE routes
                SET difficulty = %s
                WHERE route_id = %s
            """, (difficulty, route_id))
            
            updated_count += 1
            print(f"  ✓ Actualizado")
        except Exception as e:
            print(f"  ✗ Error: {e}")
        
        print()
    
    # Commit changes
    conn.commit()
    cur.close()
    conn.close()
    
    print("=" * 70)
    print(f"✓ {updated_count} ruta(s) actualizada(s) correctamente")
    print("=" * 70)
    print()

if __name__ == "__main__":
    try:
        update_route_difficulties()
    except Exception as e:
        print(f"✗ Error durante la actualización: {e}")
        sys.exit(1)
