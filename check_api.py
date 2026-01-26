#!/usr/bin/env python3
"""Check API endpoint to see what's being returned"""

import requests

url = 'https://tfg-rutes-senderisme.onrender.com/routes'
try:
    r = requests.get(url, timeout=10)
    routes = r.json()
    print("API Response Status:", r.status_code)
    print("Total routes:", len(routes))
    print()
    print("First 3 routes:")
    for route in routes[:3]:
        print(f"  - {route['name']}: difficulty='{route['difficulty']}', distance={route['distance_km']}km")
except Exception as e:
    print(f"Error: {e}")
