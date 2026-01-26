#!/usr/bin/env python3
"""Test the API routes endpoint to see what's being returned"""

import requests
import json

API_BASE_URL = "http://localhost:5000"  # Cambia según tu configuración

def test_routes_api():
    """Test GET /routes endpoint"""
    
    print("=" * 80)
    print("TEST: GET /routes API")
    print("=" * 80)
    print()
    
    try:
        url = f"{API_BASE_URL}/routes"
        print(f"Llamando a: {url}")
        print()
        
        response = requests.get(url, timeout=5)
        
        print(f"Status Code: {response.status_code}")
        print()
        
        if response.status_code == 200:
            routes = response.json()
            print(f"Total de rutas: {len(routes)}")
            print()
            
            print(f"{'ID':<5} {'Nombre':<30} {'Dist':<8} {'Elevation':<12} {'Difficulty':<15} {'Time'}")
            print("-" * 80)
            
            for r in routes:
                route_id = r.get('route_id', '')
                name = (r.get('name', '')[:27] + '...') if len(r.get('name', '')) > 30 else r.get('name', '')
                distance = f"{r.get('distance_km', 0):.1f}km"
                elevation = f"{r.get('elevation_gain', 0)}m"
                difficulty = r.get('difficulty', 'N/A')
                time = r.get('estimated_time', '')
                
                print(f"{route_id:<5} {name:<30} {distance:<8} {elevation:<12} {difficulty:<15} {time}")
            
            print()
            print("=" * 80)
            print("Respuesta JSON completa:")
            print("=" * 80)
            print(json.dumps(routes, indent=2, ensure_ascii=False))
        else:
            print(f"Error: {response.text}")
    
    except Exception as e:
        print(f"❌ Error conectando a API: {e}")
        print()
        print("💡 Verifica que:")
        print("   1. El backend Flask está corriendo (python app.py)")
        print("   2. La URL es correcta: http://localhost:5000")
        print("   3. La BD está accesible")

if __name__ == "__main__":
    test_routes_api()
