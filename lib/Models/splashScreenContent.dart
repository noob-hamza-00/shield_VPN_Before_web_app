class Splashscreencontent {
  String image;
  String title;
  String description;

  Splashscreencontent({
    required this.image,
    required this.title,
    required this.description,
  });
}

List<Splashscreencontent> contents = [
  Splashscreencontent(
    title: '100% safe and secure',
    image: 'assets/images/safe.svg',
    description: 'Experience secure and private internet browsing with a Virtual Private Network (VPN). By encrypting your connection and hiding your IP address, Stay anonymous, safe, and in control every time you go online.',
  ),
  Splashscreencontent(
    title: 'Fast and Reliable',
    image: 'assets/images/fastloading.svg',
    description: 'Enjoy high-speed connections with no interruptions. Designed for performance, it ensures smooth streaming, fast downloads, and seamless browsing without buffering or lag. Stay connected without compromising speed or stability.',
  ),
  Splashscreencontent(
    title: 'Global Access',
    image: 'assets/images/speed.svg',
    description: 'Access content from anywhere in the world. Bypass geo-restrictions to stream shows, access websites, and use apps that may be unavailable in your region and enjoy the freedom to explore global content without limits.',
  ),
];