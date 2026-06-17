import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utile/app_colors.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_IntroPageData> _pages = const [
    _IntroPageData(
      image: "assets/images/intro-one.png",
      title: 'Connected Customer Experience',
      description:
      'Bring customer data, communications, and business processes together in one intelligent CRM platform.',
    ),
    _IntroPageData(
      image: "assets/images/intro-two.png",
      title: 'Engage with Every Opportunity',
      description:
      'Track interactions, manage follow-ups, and build lasting customer relationships through effective communication.',
    ),
    _IntroPageData(
      image: "assets/images/intro-three.png",
      title: 'Make Every Decision Count',
      description:
      'Transform business data into actionable insights with advanced analytics and performance monitoring.',
    ),
  ];

  void _nextPage() async{
    if (_currentPage == _pages.length - 1) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('introDone', true);

      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _skipIntro() async{
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('introDone', true);

    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget pageIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        _pages.length,
            (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: _currentPage == index ? 28 : 9,
          height: 9,
          decoration: BoxDecoration(
            color: _currentPage == index
                ? Colors.white
                : Colors.white.withOpacity(0.35),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isLastPage = _currentPage == _pages.length - 1;
    final bool showPreviousButton = _currentPage >= 1;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -70,
              child: CircleAvatar(
                radius: 145,
                backgroundColor: Colors.white.withOpacity(0.07),
              ),
            ),

            Positioned(
              top: 180,
              left: -85,
              child: CircleAvatar(
                radius: 115,
                backgroundColor: Colors.white.withOpacity(0.06),
              ),
            ),

            Positioned(
              bottom: -90,
              right: -80,
              child: CircleAvatar(
                radius: 140,
                backgroundColor: Colors.white.withOpacity(0.05),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Azcentrix Connect',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                        TextButton(
                          onPressed: _skipIntro,
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.86),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final page = _pages[index];

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 26),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [

                              Container(
                                width: double.infinity,
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(24),
                                    child: SizedBox(
                                      height: 180,
                                      width: 180,
                                      child: Image.asset(
                                        page.image,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 52),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.18),
                                  ),
                                ),
                                child: Text(
                                  'Step ${index + 1} of ${_pages.length}',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.86),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 22),

                              Text(
                                page.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 31,
                                  height: 1.18,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.2,
                                ),
                              ),

                              const SizedBox(height: 18),

                              Text(
                                page.description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 16,
                                  height: 1.55,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  pageIndicator(),

                  const SizedBox(height: 34),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 34),
                    child: Row(
                      children: [
                        if (showPreviousButton)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _previousPage,
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 19,
                              ),
                              label: const Text('Previous'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 56),
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withOpacity(0.42),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),

                        if (showPreviousButton) const SizedBox(width: 14),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: _nextPage,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 56),
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primaryDeep,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  isLastPage ? 'Get Started' : 'Next',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  isLastPage
                                      ? Icons.check_circle_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroPageData {
  final String image;
  final String title;
  final String description;

  const _IntroPageData({
    required this.image,
    required this.title,
    required this.description,
  });
}