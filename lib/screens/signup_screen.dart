import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dashboard_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String selectedPurpose = 'Personal Use';

  final List<String> purposeOptions = [
    'Personal Use',
    'Office Work',
    'College Documents',
    'Team Collaboration',
    'Other'
  ];

  bool isLoading = false;

  Future<bool> isUsernameUnique(String username) async {
    final response = await Supabase.instance.client
        .from('app_users')
        .select('username')
        .eq('username', username)
        .maybeSingle();

    return response == null;
  }

  Future<void> signUpUser() async {
    final fullName = fullNameController.text.trim();
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (fullName.isEmpty ||
        username.isEmpty ||
        email.isEmpty ||
        password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required.")),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final isUnique = await isUsernameUnique(username);
      if (!isUnique) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Username already exists.")),
        );
        setState(() => isLoading = false);
        return;
      }

      final response = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
      );

      final userId = response.user?.id;
      if (userId == null) {
        throw Exception("Signup failed: No user returned.");
      }

      final insertResponse = await Supabase.instance.client
          .from('app_users')
          .insert({
        'id': userId,
        'full_name': fullName,
        'username': username,
        'email': email,
        'purpose': selectedPurpose,
      })
          .select();

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    } on AuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Auth Error: ${e.message}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A3D62),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Center(
                child: Image.asset(
                  'assets/images/intellispace_logo.png',
                  height: 120,
                ),
              ),
              const SizedBox(height: 40),

              const Text(
                "Create Your Account",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Roboto',
                ),
              ),
              const SizedBox(height: 30),

              buildTextField(controller: fullNameController, hint: "Full Name", icon: Icons.person),
              const SizedBox(height: 16),
              buildTextField(controller: usernameController, hint: "Username (Unique)", icon: Icons.alternate_email),
              const SizedBox(height: 16),
              buildTextField(controller: emailController, hint: "Email", icon: Icons.email),
              const SizedBox(height: 16),
              buildTextField(controller: passwordController, hint: "Password", icon: Icons.lock, obscure: true),
              const SizedBox(height: 16),

              // Purpose Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedPurpose,
                  dropdownColor: const Color(0xFF0A3D62),
                  decoration: const InputDecoration(border: InputBorder.none),
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  style: const TextStyle(color: Colors.white),
                  items: purposeOptions.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value, style: const TextStyle(color: Colors.white70)),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() {
                      selectedPurpose = newValue!;
                    });
                  },
                ),
              ),
              const SizedBox(height: 30),

              // Signup Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : signUpUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0A3D62),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator()
                      : const Text(
                    'Sign Up',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Go to Login
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  "Already have an account? Login",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
        prefixIcon: Icon(icon, color: Colors.white70),
      ),
    );
  }
}
