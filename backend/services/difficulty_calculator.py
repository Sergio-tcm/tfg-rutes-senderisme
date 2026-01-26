"""
Difficulty calculator for hiking routes.
Uses standard hiking formulas: distance, elevation gain, and estimated time.

Formula used: Modified Tobler's hiking function
- Distance effect: km
- Elevation gain effect: meters gained
- Time estimation: based on distance and elevation
- Final difficulty: Easy, Moderate, Difficult, Very Difficult

Standard hiking scales:
- Easy: suitable for all ages, minimal elevation
- Moderate: some fitness required, moderate elevation
- Difficult: good fitness required, significant elevation
- Very Difficult: excellent fitness required, steep climbs
"""

def calculate_difficulty(distance_km: float, elevation_gain: int, estimated_time: str = None, lang: str = 'es') -> str:
    """
    Calculate route difficulty based on hiking parameters.
    
    Args:
        distance_km: Distance in kilometers
        elevation_gain: Total elevation gain in meters
        estimated_time: Estimated time as string (e.g., "2:30", "2h30m")
        lang: Language for output ('es' for Spanish, 'ca' for Catalan)
    
    Returns:
        Difficulty level: 
        - Spanish: "Fácil", "Moderada", "Difícil", "Muy Difícil"
        - Catalan: "Fàcil", "Mitjana", "Difícil", "Molt Difícil"
    """
    
    # Default values for invalid inputs
    if distance_km is None or distance_km < 0:
        distance_km = 0
    if elevation_gain is None or elevation_gain < 0:
        elevation_gain = 0
    
    # Convert estimated_time string to minutes if provided
    time_minutes = None
    if estimated_time:
        time_minutes = _parse_time_to_minutes(estimated_time)
    
    # Calculate hiking difficulty score using Tobler's hiking function
    # Modified formula: Difficulty Score = Distance + (Elevation Gain / 100)
    # This is a common formula used in hiking apps
    difficulty_score = distance_km + (elevation_gain / 100)
    
    # Alternative: If we have time estimate, use it to validate/refine the score
    # Average hiking speed: ~4 km/h on flat terrain
    # With elevation: add ~0.5 hours per 300m of elevation
    if time_minutes and time_minutes > 0:
        expected_time_hours = distance_km / 4 + (elevation_gain / 300) * 0.5
        expected_time_minutes = expected_time_hours * 60
        
        # If actual time significantly differs, adjust difficulty score
        # (might indicate terrain difficulty not captured by distance/elevation)
        if expected_time_minutes > 0:
            time_ratio = time_minutes / expected_time_minutes
            # If hike takes longer than expected, it's harder
            if time_ratio > 1.2:
                difficulty_score *= time_ratio * 0.3  # Apply small adjustment
    
    # Classify based on standard hiking difficulty scales
    # These thresholds are standard in European hiking
    if difficulty_score < 5:
        if lang == 'ca':
            return "Fàcil"
        return "Fácil"
    elif difficulty_score < 15:
        if lang == 'ca':
            return "Mitjana"
        return "Moderada"
    elif difficulty_score < 30:
        return "Difícil"
    else:
        if lang == 'ca':
            return "Molt Difícil"
        return "Muy Difícil"


def _parse_time_to_minutes(time_str: str) -> int:
    """
    Parse time string to minutes.
    Supports formats: "2:30", "2h30m", "2h", "30m", "2 hours 30 minutes"
    
    Args:
        time_str: Time string
    
    Returns:
        Total minutes as integer
    """
    if not time_str:
        return None
    
    time_str = time_str.strip().lower()
    
    total_minutes = 0
    
    # Handle formats with 'h' and 'm'
    if 'h' in time_str or 'm' in time_str:
        parts = time_str.replace('h', ' h ').replace('m', ' m ').split()
        i = 0
        while i < len(parts):
            try:
                if i + 1 < len(parts):
                    num = float(parts[i])
                    unit = parts[i + 1]
                    if unit == 'h':
                        total_minutes += int(num * 60)
                        i += 2
                    elif unit == 'm':
                        total_minutes += int(num)
                        i += 2
                    else:
                        i += 1
                else:
                    i += 1
            except (ValueError, IndexError):
                i += 1
    
    # Handle colon format (e.g., "2:30")
    elif ':' in time_str:
        parts = time_str.split(':')
        try:
            hours = int(parts[0])
            minutes = int(parts[1])
            total_minutes = hours * 60 + minutes
        except (ValueError, IndexError):
            return None
    
    return total_minutes if total_minutes > 0 else None


def get_difficulty_score(distance_km: float, elevation_gain: int) -> float:
    """
    Get raw difficulty score (for filtering/sorting in recommendations).
    
    Args:
        distance_km: Distance in kilometers
        elevation_gain: Total elevation gain in meters
    
    Returns:
        Raw difficulty score (float)
    """
    if distance_km is None or distance_km < 0:
        distance_km = 0
    if elevation_gain is None or elevation_gain < 0:
        elevation_gain = 0
    
    return distance_km + (elevation_gain / 100)
