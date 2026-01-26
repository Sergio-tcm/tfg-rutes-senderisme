#!/usr/bin/env python3
"""Debug script to check what difficulties are in the database"""

from db import get_connection

def check_route_difficulties():
    conn = get_connection()
    cur = conn.cursor()
    
    print("=" * 80)
    print("DIAGNÓSTICO DE DIFICULTADES EN LA BD")
    print("=" * 80)
    print()
    
    # Get all routes
    cur.execute("""
        SELECT route_id, name, distance_km, elevation_gain, estimated_time, difficulty
        FROM routes
        ORDER BY route_id ASC
    """)
    
    routes = cur.fetchall()
    
    if not routes:
        print("No hay rutas en la BD")
        return
    
    print(f"Total de rutas: {len(routes)}")
    print()
    print(f"{'ID':<5} {'Nombre':<30} {'Dist(km)':<10} {'Desnivel':<10} {'Tiempo':<10} {'Dificultad':<15}")
    print("-" * 80)
    
    difficulties_found = set()
    
    for route_id, name, distance_km, elevation_gain, estimated_time, difficulty in routes:
        difficulties_found.add(difficulty)
        name_display = (name[:27] + '...') if len(name) > 30 else name
        time_display = (estimated_time[:9] + '...') if isinstance(estimated_time, str) and len(estimated_time) > 10 else str(estimated_time or '')
        
        print(f"{route_id:<5} {name_display:<30} {float(distance_km or 0):<10.1f} {int(elevation_gain or 0):<10} {time_display:<10} {difficulty:<15}")
    
    print()
    print("=" * 80)
    print(f"Dificultades encontradas en BD: {difficulties_found}")
    print("=" * 80)
    
    cur.close()
    conn.close()

if __name__ == "__main__":
    check_route_difficulties()
