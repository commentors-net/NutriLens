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
import NutriLensUsers from '@pages/NutriLensUsers';
import config from '@/config';

function AppContent() {
  const [isLoggedIn, setIsLoggedIn] = useState(false);
  const [username, setUsername] = useState('');
  const [allowedSystems, setAllowedSystems] = useState<string[]>([]);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const navigate = useNavigate();
  const theme = useTheme();
  const isMobile = useMediaQuery(theme.breakpoints.down('md'));

  // Check login status on mount and whenever localStorage changes
  const checkLoginStatus = () => {
    const token = localStorage.getItem('access_token');
    const user = localStorage.getItem('username');
    const systemsRaw = localStorage.getItem('allowed_systems');
    const systems = systemsRaw ? JSON.parse(systemsRaw) : [];
    if (token && user) {
      setIsLoggedIn(true);
      setUsername(user);
      setAllowedSystems(Array.isArray(systems) ? systems : []);
    } else {
      setIsLoggedIn(false);
      setUsername('');
      setAllowedSystems([]);
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
    localStorage.removeItem('allowed_systems');
    localStorage.removeItem('selected_system');
    setIsLoggedIn(false);
    setUsername('');
    setAllowedSystems([]);
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

  const selectedSystem = localStorage.getItem('selected_system') || '';
  const canUseLeaveTracker = allowedSystems.includes('leave-tracker');
  const canUseNutriLens = allowedSystems.includes('nutrilens');

  const navItems = isLoggedIn
    ? selectedSystem === 'nutrilens'
      ? [
          { label: 'Apps', path: '/app-select' },
          { label: 'NutriLens', path: '/nutrilens' },
          { label: 'Users', path: '/nutrilens/users' },
        ]
      : selectedSystem === 'leave-tracker'
      ? [
          { label: 'Apps', path: '/app-select' },
          { label: 'Dashboard', path: '/dashboard' },
          { label: 'Reports', path: '/reports' },
          { label: 'Smart ID', path: '/smart-identification' },
          { label: 'Settings', path: '/settings' },
        ]
      : [{ label: 'Apps', path: '/app-select' }]
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
            Unified Platform
          </Typography>
          {!isMobile && isLoggedIn ? (
            <>
              <Typography variant="body2" sx={{ mr: 2, display: { xs: 'none', sm: 'block' } }}>
                {username}
              </Typography>
              <Button color="inherit" component={Link} to="/app-select" size="small">
                Apps
              </Button>
              {selectedSystem === 'nutrilens' && canUseNutriLens ? (
                <>
                  <Button color="inherit" component={Link} to="/nutrilens" size="small">
                    NutriLens
                  </Button>
                  <Button color="inherit" component={Link} to="/nutrilens/users" size="small">
                    Users
                  </Button>
                </>
              ) : selectedSystem === 'leave-tracker' && canUseLeaveTracker ? (
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
              ) : null}
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
          <Route
            path="/"
            element={<Navigate to={isLoggedIn ? '/app-select' : '/login'} replace />}
          />
          <Route
            path="/app-select"
            element={isLoggedIn ? <AppSelect /> : <Navigate to="/login" replace />}
          />
          <Route path="/login" element={<Navigate to="/leave-tracker/login" replace />} />
          <Route
            path="/leave-tracker/login"
            element={isLoggedIn ? <Navigate to="/app-select" replace /> : <Login />}
          />
          <Route
            path="/nutrilens/login"
            element={isLoggedIn ? <Navigate to="/app-select" replace /> : <Login />}
          />
          <Route 
            path="/leave-tracker/register" 
            element={
              config.features.enableRegistration && !isLoggedIn ? (
                <Register />
              ) : (
                <Navigate to={isLoggedIn ? '/app-select' : '/leave-tracker/login'} replace />
              )
            } 
          />
          <Route
            path="/nutrilens"
            element={isLoggedIn && selectedSystem === 'nutrilens' && canUseNutriLens ? <NutriLensPortal /> : <Navigate to="/app-select" replace />}
          />
          <Route
            path="/nutrilens/users"
            element={isLoggedIn && selectedSystem === 'nutrilens' && canUseNutriLens ? <NutriLensUsers /> : <Navigate to="/app-select" replace />}
          />
          <Route
            path="/dashboard"
            element={isLoggedIn && selectedSystem === 'leave-tracker' && canUseLeaveTracker ? <Dashboard /> : <Navigate to="/app-select" replace />}
          />
          <Route
            path="/reports"
            element={isLoggedIn && selectedSystem === 'leave-tracker' && canUseLeaveTracker ? <Reports /> : <Navigate to="/app-select" replace />}
          />
          <Route
            path="/smart-identification"
            element={isLoggedIn && selectedSystem === 'leave-tracker' && canUseLeaveTracker ? <SmartIdentification /> : <Navigate to="/app-select" replace />}
          />
          <Route
            path="/settings"
            element={isLoggedIn && selectedSystem === 'leave-tracker' && canUseLeaveTracker ? <Settings /> : <Navigate to="/app-select" replace />}
          />
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
