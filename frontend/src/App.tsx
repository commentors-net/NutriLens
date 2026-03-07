import { BrowserRouter as Router, Routes, Route, Link, useNavigate, Navigate } from 'react-router-dom';
import { 
  AppBar, 
  Toolbar, 
  Typography, 
  Container, 
  Button, 
  IconButton, 
  Drawer, 
  List, 
  ListItem, 
  ListItemButton,
  ListItemText,
  Box,
  useTheme,
  useMediaQuery
} from '@mui/material';
import MenuIcon from '@mui/icons-material/Menu';
import { useState, useEffect } from 'react';
import Login from '@pages/Login';
import Register from '@pages/Register';
import Dashboard from '@pages/Dashboard';
import Settings from '@pages/Settings';
import SmartIdentification from '@pages/SmartIdentification';
import Reports from '@pages/Reports';
import AppSelect from '@pages/AppSelect';
import NutriLensPortal from '@pages/NutriLensPortal';
import config from '@/config';

function AppContent() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [username, setUsername] = useState('');
  const [drawerOpen, setDrawerOpen] = useState(false);
  const navigate = useNavigate();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));

  // Check login status on mount and whenever localStorage changes
  const checkLoginStatus = () => {
    const token = localStorage.getItem('access_token');
    const user = localStorage.getItem('username');
    if (token && user) {
      setIsLoggedIn(true);
      setUsername(user);
    } else {
      setIsLoggedIn(false);
      setUsername('');
    }
  };

  useEffect(() => {
    checkLoginStatus();
    
    // Listen for storage events (for multi-tab sync)
    window.addEventListener('storage', checkLoginStatus);
    
    return () => {
      window.removeEventListener('storage', checkLoginStatus);
    };
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('access_token');
    localStorage.removeItem('username');
    setIsLoggedIn(false);
    setUsername('');
    setDrawerOpen(false);
    navigate('/login');
  };

  const handleDrawerToggle = () => {
    setDrawerOpen(!drawerOpen);
  };

  const handleNavClick = (path: string) => {
    navigate(path);
    setDrawerOpen(false);
  };

  const selectedSystem = localStorage.getItem('selected_system') || 'leave-tracker';

  const navItems = isLoggedIn
    ? selectedSystem === 'nutrilens'
      ? [
          { label: 'Apps', path: '/' },
          { label: 'NutriLens', path: '/nutrilens' },
        ]
      : [
          { label: 'Apps', path: '/' },
          { label: 'Dashboard', path: '/dashboard' },
          { label: 'Reports', path: '/reports' },
          { label: 'Smart ID', path: '/smart-identification' },
          { label: 'Settings', path: '/settings' },
        ]
    : [];

  return (
    <div>
      <AppBar position="static">
        <Toolbar>
          {isMobile && isLoggedIn && (
            <IconButton
              color="inherit"
              edge="start"
              onClick={handleDrawerToggle}
              sx={{ mr: 2 }}
            >
              <MenuIcon />
            </IconButton>
          )}
          <Typography variant="h6" sx={{ flexGrow: 1, cursor: 'pointer' }} component={Link} to="/" style={{ textDecoration: 'none', color: 'inherit' }}>
            Leave Tracker
          </Typography>
          {!isMobile && isLoggedIn ? (
            <>
              <Typography variant="body2" sx={{ mr: 2, display: { xs: 'none', sm: 'block' } }}>
                {username}
              </Typography>
              <Button color="inherit" component={Link} to="/" size="small">
                Apps
              </Button>
              {selectedSystem === 'nutrilens' ? (
                <Button color="inherit" component={Link} to="/nutrilens" size="small">
                  NutriLens
                </Button>
              ) : (
                <>
                  <Button color="inherit" component={Link} to="/dashboard" size="small">
                    Dashboard
                  </Button>
                  <Button color="inherit" component={Link} to="/reports" size="small">
                    Reports
                  </Button>
                  <Button color="inherit" component={Link} to="/smart-identification" size="small" sx={{ display: { xs: 'none', lg: 'inline-flex' } }}>
                    Smart ID
                  </Button>
                  <Button color="inherit" component={Link} to="/settings" size="small">
                    Settings
                  </Button>
                </>
              )}
              <Button color="inherit" onClick={handleLogout} size="small">
                Logout
              </Button>
            </>
          ) : !isMobile && !isLoggedIn ? (
            <>
              <Button color="inherit" component={Link} to="/login" size="small">
                Login
              </Button>
              {config.features.enableRegistration && (
                <Button color="inherit" component={Link} to="/leave-tracker/register" size="small">
                  Register
                </Button>
              )}
            </>
          ) : !isLoggedIn ? (
            <Box>
              <Button color="inherit" component={Link} to="/login" size="small">
                Login
              </Button>
              {config.features.enableRegistration && (
                <Button color="inherit" component={Link} to="/leave-tracker/register" size="small">
                  Register
                </Button>
              )}
            </Box>
          ) : null}
        </Toolbar>
      </AppBar>
      
      {/* Mobile Drawer */}
      <Drawer
        anchor="left"
        open={drawerOpen}
        onClose={handleDrawerToggle}
      >
        <Box sx={{ width: 250, pt: 2 }}>
          <Typography variant="h6" sx={{ px: 2, mb: 2 }}>
            {username}
          </Typography>
          <List>
            {navItems.map((item) => (
              <ListItem key={item.path} disablePadding>
                <ListItemButton onClick={() => handleNavClick(item.path)}>
                  <ListItemText primary={item.label} />
                </ListItemButton>
              </ListItem>
            ))}
            <ListItem disablePadding>
              <ListItemButton onClick={handleLogout}>
                <ListItemText primary="Logout" />
              </ListItemButton>
            </ListItem>
          </List>
        </Box>
      </Drawer>
      <Container>
        <Routes>
          <Route path="/" element={<AppSelect />} />
          <Route path="/login" element={<Navigate to="/leave-tracker/login" replace />} />
          <Route path="/leave-tracker/login" element={<Login />} />
          <Route path="/nutrilens/login" element={<Login />} />
          <Route 
            path="/leave-tracker/register" 
            element={
              config.features.enableRegistration ? (
                <Register />
              ) : (
                <Navigate to="/leave-tracker/login" replace />
              )
            } 
          />
          <Route path="/nutrilens" element={<NutriLensPortal />} />
          <Route path="/dashboard" element={<Dashboard />} />
          <Route path="/reports" element={<Reports />} />
          <Route path="/smart-identification" element={<SmartIdentification />} />
          <Route path="/settings" element={<Settings />} />
        </Routes>
      </Container>
    </div>
  );
}

function App() {
  return (
    <Router>
      <AppContent />
    </Router>
  );
}

export default App;
