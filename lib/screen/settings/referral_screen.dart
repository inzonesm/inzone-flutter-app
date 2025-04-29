import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:inzone/services/monetization_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ReferralScreen extends StatefulWidget {
  const ReferralScreen({super.key});

  @override
  State<ReferralScreen> createState() => _ReferralScreenState();
}

class _ReferralScreenState extends State<ReferralScreen> {
  final MonetizationService _monetizationService = MonetizationService();
  String? _referralCode;
  String? _referralLink;
  int _referralCount = 0;
  int _totalEarnings = 0;
  List<Map<String, dynamic>> _referralHistory = [];
  bool _isLoading = true;

  Future<void> _launchInBrowser(String url) async {
    if (await canLaunch(url)) {
      await launch(
        url,
        forceSafariVC: false,
        forceWebView: false,
        headers: <String, String>{"header_key": "header_value"},
      );
    } else {
      throw "Could not launch $url";
    }
  }

  @override
  void initState() {
    super.initState();
    _loadReferralData();
  }

  Future<void> _loadReferralData() async {
    try {
      // First generate a new referral code
      final generateResponse =
          await _monetizationService.generateReferralCode();
      if (generateResponse['success'] == true) {
        _referralCode = generateResponse['data']['referral_code'];
        _referralLink = 'https://inzone.ai/referral?code=$_referralCode';
      }

      // Then get the stats
      final stats = await _monetizationService.getReferralStats();
      if (stats['success'] == true) {
        setState(() {
          _referralCount = stats['data']['referral_count'];
          _totalEarnings = stats['data']['total_earnings'];
          _referralHistory = List<Map<String, dynamic>>.from(
              stats['data']['referral_history']);
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading referral data: $e')),
        );
      }
    }
  }

  Future<void> _copyReferralLink() async {
    if (_referralLink != null) {
      await Clipboard.setData(ClipboardData(text: _referralLink!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Referral link copied to clipboard')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Referral Program'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(children: [
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: ShapeDecoration(
                    color: const Color(0xFFF5F5F5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16.50, vertical: 31),
                        clipBehavior: Clip.antiAlias,
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF5F5F5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: SvgPicture.asset(
                          "icons/referral/Frame.png",
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Give \$10, Get \$10 ',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF17181C),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Refer friends to InZone, they get \$10 worth of InCash upon signing up. You get \$10 worth of InCash on us.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF17181C),
                          fontSize: 13,
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset("icons/referral/facebook.png",
                                width: 32, height: 32),
                            const SizedBox(width: 14),
                            Image.asset("icons/referral/twitter.png",
                                width: 32, height: 32),
                            const SizedBox(width: 14),
                            Image.asset("icons/referral/instagram.png",
                                width: 32, height: 32),
                            const SizedBox(width: 14),
                            Image.asset("icons/referral/tiktok.png",
                                width: 32, height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.only(left: 10),
                            width: MediaQuery.of(context).size.width,
                            height: 60,
                            decoration: ShapeDecoration(
                              color: Colors.white,
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(
                                    width: 1, color: Color(0XFFA3A3A3)),
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                    child: Text(
                                  _referralLink ?? "Loading...",
                                  style: GoogleFonts.outfit(
                                      color: const Color(0XFF5A6172),
                                      fontWeight: FontWeight.normal),
                                  maxLines: 1,
                                )),
                                IconButton(
                                    onPressed: _copyReferralLink,
                                    icon: const Icon(
                                      Icons.copy,
                                      color: Color(0XFF228AF3),
                                    ))
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          ListView.builder(
                            shrinkWrap: true,
                            itemCount: _referralHistory.length,
                            itemBuilder: (BuildContext context, int index) {
                              final referral = _referralHistory[index];
                              return Container(
                                  decoration: ShapeDecoration(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    shadows: const [
                                      BoxShadow(
                                        color: Color(0x0C6F88D1),
                                        blurRadius: 30,
                                        offset: Offset(0, 10),
                                        spreadRadius: 0,
                                      )
                                    ],
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          child: Image.asset(
                                            "assets/logo.png",
                                            width: 48,
                                            height: 48,
                                            fit: BoxFit.fill,
                                          )),
                                      const SizedBox(width: 10),
                                      Expanded(
                                          child: Column(children: [
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  'Referred User',
                                                  style: GoogleFonts.outfit(
                                                    color:
                                                        const Color(0xFF212121),
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                referral['date'] ?? 'N/A',
                                                style: GoogleFonts.outfit(
                                                  color:
                                                      const Color(0xFF999999),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ]),
                                      ])),
                                    ],
                                  ));
                            },
                          ),
                        ])),
                Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      clipBehavior: Clip.antiAlias,
                      decoration: ShapeDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment(1.00, 0.00),
                          end: Alignment(-1, 0),
                          colors: [Color(0xFF125455), Color(0xFF29BABB)],
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: Text(
                        'Sync Contacts',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )),
              ]),
            ),
    );
  }
}
