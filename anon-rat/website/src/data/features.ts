export type Feature = {
  id: string
  title: string
  blurb: string
  image: string
}

export const features: Feature[] = [
  {
    id: 'fingerprint',
    title: 'Fingerprint Spoofing',
    blurb: 'Scrubs hardware and browser signals so trackers see a quieter device profile.',
    image: '/features/fingerprint.jpg',
  },
  {
    id: 'proxy',
    title: 'Anonymous Proxy Layer',
    blurb: 'Routes selected traffic through a closed egress path for cleaner network identity.',
    image: '/features/proxy.jpg',
  },
  {
    id: 'location',
    title: 'Location Obfuscation',
    blurb: 'Keeps precise coordinates off default share paths; surfaces approximate region only.',
    image: '/features/location.jpg',
  },
  {
    id: 'ua',
    title: 'User-Agent Rotation',
    blurb: 'Rotates client signatures to break long-lived tracking pairs across sessions.',
    image: '/features/ua.jpg',
  },
  {
    id: 'dns',
    title: 'DNS Protection',
    blurb: 'Hardens resolution against trivial leak patterns on hostile public Wi‑Fi.',
    image: '/features/dns.jpg',
  },
  {
    id: 'tracker',
    title: 'Tracker Shield',
    blurb: 'Blocks a curated set of advertising and analytics domains inside the console profile.',
    image: '/features/tracker.jpg',
  },
  {
    id: 'vault',
    title: 'Encrypted Session Vault',
    blurb: 'Stores console credentials in device-backed storage with explicit remember-me control.',
    image: '/features/vault.jpg',
  },
]
