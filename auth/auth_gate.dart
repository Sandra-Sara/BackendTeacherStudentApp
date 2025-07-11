import 'package:flutter/main.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
class AuthGate extends StatelessWidget{

  const AuthGate({super.key});
  Widget build(BuildContext context){
    return StreamBuilder(
      stream: Supabase.instance.client.auth.onAuthStateChange
    )
  }
}