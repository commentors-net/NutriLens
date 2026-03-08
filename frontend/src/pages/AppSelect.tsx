import { Container, Box, Typography, Card, CardContent, CardActionArea, Grid } from '@mui/material';
import { useEffect, useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import CalendarMonthIcon from '@mui/icons-material/CalendarMonth';
import RestaurantIcon from '@mui/icons-material/Restaurant';
import { authApi } from '@services/api';

function AppSelect() {
  const navigate = useNavigate();

  const apps = [
    {
      name: 'Leave Tracker',
      description: 'Manage employee leave requests and track absences',
      icon: <CalendarMonthIcon sx={{ fontSize: 80, color: 'primary.main' }} />,
      system: 'leave-tracker',
      path: '/dashboard',
      color: '#1976d2', // MUI primary blue
    },
    {
      name: 'NutriLens',
      description: 'AI-powered food photo logging and nutrition tracking',
      icon: <RestaurantIcon sx={{ fontSize: 80, color: 'success.main' }} />,
      system: 'nutrilens',
      path: '/nutrilens',
      color: '#2e7d32', // MUI success green
    },
  ];

  const token = localStorage.getItem('access_token');
  const [allowedSystems, setAllowedSystems] = useState<string[]>(() => {
    const storedSystems = localStorage.getItem('allowed_systems');
    return storedSystems ? JSON.parse(storedSystems) : [];
  });

  const allowedApps = useMemo(
    () => apps.filter((app) => allowedSystems.includes(app.system)),
    [allowedSystems],
  );

  useEffect(() => {
    if (!token) {
      navigate('/login', { replace: true });
      return;
    }

    // Refresh from backend in case access changes server-side.
    authApi
      .me()
      .then((profile) => {
        const systems = profile.allowed_systems || [];
        localStorage.setItem('allowed_systems', JSON.stringify(systems));
        setAllowedSystems(systems);
      })
      .catch(() => {
        // Keep current local access list on transient errors.
      });
  }, [navigate, token]);

  useEffect(() => {
    if (!token) {
      return;
    }
    if (allowedApps.length === 1) {
      localStorage.setItem('selected_system', allowedApps[0].system);
      navigate(allowedApps[0].path, { replace: true });
    }
  }, [allowedApps, navigate, token]);

  const handleAppClick = (app: typeof apps[0]) => {
    localStorage.setItem('selected_system', app.system);
    window.dispatchEvent(new Event('storage'));
    navigate(app.path);
  };

  return (
    <Container maxWidth="lg">
      <Box
        sx={{
          minHeight: '80vh',
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          alignItems: 'center',
          py: 4,
        }}
      >
        <Typography variant="h3" component="h1" gutterBottom align="center" sx={{ mb: 1 }}>
          Welcome
        </Typography>
        <Typography variant="h6" color="text.secondary" align="center" sx={{ mb: 6 }}>
          Choose a system you can access
        </Typography>

        <Grid container spacing={4} justifyContent="center" maxWidth="900px">
          {allowedApps.map((app) => (
            <Grid size={{ xs: 12, sm: 6, md: 5 }} key={app.name}>
              <Card
                elevation={3}
                sx={{
                  height: '100%',
                  display: 'flex',
                  flexDirection: 'column',
                  transition: 'transform 0.2s, box-shadow 0.2s',
                  '&:hover': {
                    transform: 'translateY(-8px)',
                    boxShadow: 6,
                  },
                }}
              >
                <CardActionArea
                  onClick={() => handleAppClick(app)}
                  sx={{
                    height: '100%',
                    display: 'flex',
                    flexDirection: 'column',
                    alignItems: 'stretch',
                    justifyContent: 'flex-start',
                  }}
                >
                  <CardContent
                    sx={{
                      flex: 1,
                      display: 'flex',
                      flexDirection: 'column',
                      alignItems: 'center',
                      justifyContent: 'center',
                      textAlign: 'center',
                      p: 4,
                    }}
                  >
                    <Box sx={{ mb: 2 }}>
                      {app.icon}
                    </Box>
                    <Typography variant="h4" component="h2" gutterBottom>
                      {app.name}
                    </Typography>
                    <Typography variant="body1" color="text.secondary">
                      {app.description}
                    </Typography>
                  </CardContent>
                </CardActionArea>
              </Card>
            </Grid>
          ))}
        </Grid>

        {allowedApps.length === 0 && (
          <Typography variant="body1" color="error" sx={{ mt: 2 }}>
            No systems are enabled for your account. Please contact an administrator.
          </Typography>
        )}

        <Typography variant="body2" color="text.secondary" align="center" sx={{ mt: 6 }}>
          Part of the unified productivity platform
        </Typography>
      </Box>
    </Container>
  );
}

export default AppSelect;
