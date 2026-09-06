import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://txvxgxcdkqrzfatinrqa.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InR4dnhneGNka3FyemZhdGlucnFhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc4Nzc1OTYxMiwiZXhwIjoyMTAzMzM1NjEyfQ.uUZFbLhxtri-UEcqSw_PImapsBB1th9jJr3F1Z7Sofw', // service_role key
  );

  try {
    final res = await supabase.auth.admin.createUser(
      AdminUserAttributes(
        email: 'master@admin.com',
        password: 'masterpassword123',
        emailConfirm: true,
      ),
    );
    print('Master Admin created with ID: \${res.user?.id}');
  } catch (e) {
    print('Error creating user (might already exist): \$e');
  }
}
