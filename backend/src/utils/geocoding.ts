export async function geocodeAddress(
  address: string,
  city: string,
): Promise<{ latitude: number; longitude: number } | null> {
  const query = [address, city].filter(Boolean).join(', ');
  if (!query.trim()) return null;

  try {
    const url = new URL('https://nominatim.openstreetmap.org/search');
    url.searchParams.set('q', query);
    url.searchParams.set('format', 'json');
    url.searchParams.set('limit', '1');

    const response = await fetch(url.toString(), {
      headers: {
        'User-Agent': 'FAST-Resto-App/1.0 (contact@fast.app)',
        Accept: 'application/json',
      },
    });

    if (!response.ok) return null;

    const results = (await response.json()) as Array<{ lat: string; lon: string }>;
    if (!results.length) return null;

    return {
      latitude: parseFloat(results[0].lat),
      longitude: parseFloat(results[0].lon),
    };
  } catch {
    return null;
  }
}
