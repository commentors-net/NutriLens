import { Card, Typography, Box } from '@mui/material';

function NutriLensPortal() {
  const username = localStorage.getItem('username') || 'User';

  return (
    <Box sx={{ maxWidth: 900, mx: 'auto', mt: { xs: 2, sm: 4 }, px: { xs: 2, sm: 3 } }}>
      <Card sx={{ p: { xs: 2, sm: 3, md: 4 } }}>
        <Typography variant="h5" gutterBottom>
          NutriLens Portal
        </Typography>
        <Typography variant="body1" sx={{ mb: 2 }}>
          Welcome, {username}. You are logged in to the NutriLens system.
        </Typography>
        <Typography variant="body2" color="text.secondary">
          Mobile meal capture and analysis continues in the Flutter app. This web portal is reserved for
          unified access and future NutriLens web/admin modules.
        </Typography>
      </Card>
    </Box>
  );
}

export default NutriLensPortal;
