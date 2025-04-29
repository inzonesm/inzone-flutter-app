import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:inzone/router/routes.dart';
import 'package:inzone/screen/auth/loading_screen.dart';

class EmailLogInPage extends StatefulWidget {
  const EmailLogInPage({super.key});

  @override
  State<EmailLogInPage> createState() => _EmailLogInPageState();
}

class _EmailLogInPageState extends State<EmailLogInPage> {
  String? email;
  String? password;
  String? errorMessage;
  bool isLoading = false;

  // Helper function to convert Firebase error codes to user-friendly messages
  String getUserFriendlyErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'too-many-requests':
        return 'Too many login attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'invalid-credential':
        return 'Invalid login credentials. Please check your email and password.';
      case 'email-already-in-use':
        return 'This email is already associated with an account.';
      default:
        return e.message ?? 'Login failed. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () {
                context.pop();
              },
              child: const Icon(
                Icons.arrow_back_ios_rounded,
                size: 25,
                color: Colors.black,
              ),
            ),
            const Text(
              "Welcome Back",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
            const SizedBox(
              width: 20,
            )
          ],
        ),
        backgroundColor: Theme.of(context).canvasColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        "Let's get you back InZone",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: Colors.black),
                      ),
                    ),
                    const Text("E-mail",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(
                                0, 0), // Changes the position of the shadow
                          ),
                        ],
                      ),
                      child: TextField(
                        enabled: !isLoading,
                        decoration: const InputDecoration(
                          hintText: 'Enter E-mail',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {
                            email = value;
                            errorMessage = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    const Text("Password",
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(
                      height: 10,
                    ),
                    Container(
                      padding: const EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.0),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.5),
                            spreadRadius: 1,
                            blurRadius: 3,
                            offset: const Offset(
                                0, 0), // Changes the position of the shadow
                          ),
                        ],
                      ),
                      child: TextField(
                        enabled: !isLoading,
                        obscureText: true,
                        decoration: const InputDecoration(
                          hintText: 'Enter Password',
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {
                            password = value;
                            errorMessage = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    Center(
                      child: ElevatedButton(
                          onPressed: isLoading
                              ? null
                              : () async {
                                  if (email == null ||
                                      email!.isEmpty ||
                                      password == null ||
                                      password!.isEmpty) {
                                    setState(() {
                                      errorMessage = "Please fill all fields!";
                                    });
                                  } else {
                                    setState(() {
                                      isLoading = true;
                                      errorMessage = null;
                                    });

                                    // Navigate to full loading screen instead of dialog
                                    context.push(Routes.splash);

                                    // Create a future that completes after at least 1 second
                                    final loadingDelay = Future.delayed(
                                        const Duration(seconds: 1));

                                    try {
                                      // Login process
                                      final authResult = await FirebaseAuth
                                          .instance
                                          .signInWithEmailAndPassword(
                                        email: email!,
                                        password: password!,
                                      );

                                      // Wait for minimum loading time
                                      await loadingDelay;

                                      // Only navigate if the widget is still mounted
                                      if (mounted) {
                                        // Navigate directly to home
                                        context.go(Routes.home);
                                      }
                                    } on FirebaseAuthException catch (e) {
                                      // Wait for minimum loading time
                                      await loadingDelay;

                                      // Pop loading screen and return to login screen
                                      if (mounted) Navigator.pop(context);

                                      setState(() {
                                        isLoading = false;
                                        errorMessage =
                                            getUserFriendlyErrorMessage(e);
                                      });
                                    } catch (e) {
                                      // Wait for minimum loading time
                                      await loadingDelay;

                                      // Pop loading screen and return to login screen
                                      if (mounted) Navigator.pop(context);

                                      setState(() {
                                        isLoading = false;
                                        errorMessage =
                                            "An unexpected error occurred. Please try again.";
                                      });
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              elevation: 10,
                              disabledBackgroundColor:
                                  Colors.blue.withOpacity(0.6),
                              //elevation of button
                              shape: RoundedRectangleBorder(
                                  //to set border radius to button
                                  side: const BorderSide(
                                      width: 1, color: Colors.blue),
                                  borderRadius: BorderRadius.circular(30)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 120,
                                  vertical: 20) //content padding inside button
                              ),
                          child: Text(
                            isLoading ? "Logging in..." : "Log in",
                            style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          )),
                    ),
                    const SizedBox(
                      height: 30,
                    ),
                    if (errorMessage != null)
                      Center(
                        child: Text(
                          errorMessage!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 15),
                          textAlign: TextAlign.center,
                        ),
                      )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
