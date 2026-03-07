import { useState, useEffect } from "react";
import {
  Card,
  Typography,
  TextField,
  Button,
  Box,
  List,
  ListItem,
  ListItemText,
  Divider,
  Tabs,
  Tab,
  IconButton,
  Dialog,
  DialogTitle,
  DialogContent,
  DialogActions,
  Alert,
  CircularProgress,
} from "@mui/material";
import EditIcon from "@mui/icons-material/Edit";
import DeleteIcon from "@mui/icons-material/Delete";
import RestoreIcon from "@mui/icons-material/Restore";
import { peopleApi, typesApi, aiInstructionsApi } from "@services/api";
import type { Person, LeaveType, AIInstructions } from "@services/api";

interface TabPanelProps {
  children?: React.ReactNode;
  index: number;
  value: number;
}

function TabPanel(props: TabPanelProps) {
  const { children, value, index, ...other } = props;
  return (
    <div
      role="tabpanel"
      hidden={value !== index}
      id={`settings-tabpanel-${index}`}
      aria-labelledby={`settings-tab-${index}`}
      {...other}
    >
      {value === index && <Box sx={{ p: { xs: 2, sm: 3 } }}>{children}</Box>}
    </div>
  );
}

export default function Settings() {
  const [people, setPeople] = useState<Person[]>([]);
  const [types, setTypes] = useState<LeaveType[]>([]);
  const [newPersonName, setNewPersonName] = useState("");
  const [newTypeName, setNewTypeName] = useState("");
  const [tabValue, setTabValue] = useState(0);
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [editItem, setEditItem] = useState<any>(null);
  const [editName, setEditName] = useState("");
  const [editType, setEditType] = useState<"person" | "type">("person");
  
  // AI Instructions state
  const [aiInstructions, setAiInstructions] = useState<AIInstructions | null>(null);
  const [aiInstructionsText, setAiInstructionsText] = useState("");
  const [aiLoading, setAiLoading] = useState(false);
  const [aiSuccess, setAiSuccess] = useState(false);
  const [aiError, setAiError] = useState("");

  useEffect(() => {
    fetchData();
    fetchAiInstructions();
  }, []);

  const fetchAiInstructions = async () => {
    try {
      const data = await aiInstructionsApi.get();
      setAiInstructions(data);
      setAiInstructionsText(data.instructions);
    } catch (err) {
      console.error("Failed to fetch AI instructions", err);
    }
  };

  const fetchData = async () => {
    try {
      const [peopleData, typesData] = await Promise.all([
        peopleApi.getAll(),
        typesApi.getAll()
      ]);
      setPeople(peopleData);
      setTypes(typesData);
    } catch (err) {
      console.error("Failed to fetch data", err);
      alert("Failed to load data. Please login again.");
    }
  };

  const handleAddPerson = async () => {
    if (!newPersonName.trim()) return;
    try {
      await peopleApi.create({ name: newPersonName });
      setNewPersonName("");
      fetchData();
    } catch (err) {
      alert("Failed to add person");
    }
  };

  const handleAddType = async () => {
    if (!newTypeName.trim()) return;
    try {
      await typesApi.create({ name: newTypeName });
      setNewTypeName("");
      fetchData();
    } catch (err) {
      alert("Failed to add type");
    }
  };

  const handleTabChange = (_event: React.SyntheticEvent, newValue: number) => {
    setTabValue(newValue);
  };

  const handleEditClick = (item: any, type: "person" | "type") => {
    setEditItem(item);
    setEditName(item.name);
    setEditType(type);
    setEditDialogOpen(true);
  };

  const handleEditSave = async () => {
    if (!editName.trim() || !editItem) return;
    try {
      if (editType === "person") {
        await peopleApi.update(editItem.id, { name: editName });
      } else {
        await typesApi.update(editItem.id, { name: editName });
      }
      setEditDialogOpen(false);
      setEditItem(null);
      setEditName("");
      fetchData();
    } catch (err) {
      alert(`Failed to update ${editType}`);
    }
  };

  const handleDelete = async (id: number, type: "person" | "type") => {
    if (!confirm(`Are you sure you want to delete this ${type}?`)) return;
    try {
      if (type === "person") {
        await peopleApi.delete(id);
      } else {
        await typesApi.delete(id);
      }
      fetchData();
    } catch (err) {
      alert(`Failed to delete ${type}`);
    }
  };

  const handleSaveAiInstructions = async () => {
    setAiLoading(true);
    setAiError("");
    setAiSuccess(false);
    try {
      const updated = await aiInstructionsApi.update({ instructions: aiInstructionsText });
      setAiInstructions(updated);
      setAiSuccess(true);
      setTimeout(() => setAiSuccess(false), 3000);
    } catch (err) {
      setAiError("Failed to save AI instructions");
    } finally {
      setAiLoading(false);
    }
  };

  const handleResetAiInstructions = async () => {
    if (!confirm("Are you sure you want to reset to default AI instructions?")) return;
    setAiLoading(true);
    setAiError("");
    try {
      const reset = await aiInstructionsApi.reset();
      setAiInstructions(reset);
      setAiInstructionsText(reset.instructions);
      setAiSuccess(true);
      setTimeout(() => setAiSuccess(false), 3000);
    } catch (err) {
      setAiError("Failed to reset AI instructions");
    } finally {
      setAiLoading(false);
    }
  };

  return (
    <Box sx={{ mt: { xs: 2, sm: 4 }, mx: "auto", maxWidth: 900, px: { xs: 2, sm: 3 } }}>
      <Card>
        <Box sx={{ borderBottom: 1, borderColor: "divider" }}>
          <Tabs 
            value={tabValue} 
            onChange={handleTabChange} 
            aria-label="settings tabs"
            variant="scrollable"
            scrollButtons="auto"
          >
            <Tab label="People" />
            <Tab label="Leave Types" />
            <Tab label="AI Instructions" />
          </Tabs>
      </Box>
      
      <TabPanel value={tabValue} index={0}>
        <Typography variant="h6" gutterBottom>
          Manage People
        </Typography>
        <Box sx={{ display: "flex", gap: 2, mb: 2 }}>
          <TextField
            label="Person Name"
            value={newPersonName}
            onChange={(e) => setNewPersonName(e.target.value)}
            fullWidth
            onKeyPress={(e) => e.key === "Enter" && handleAddPerson()}
          />
          <Button variant="contained" onClick={handleAddPerson}>
            Add
          </Button>
        </Box>
        <Divider sx={{ my: 2 }} />
        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
          {people.length} {people.length === 1 ? "person" : "people"}
        </Typography>
        <List>
          {people.length === 0 ? (
            <ListItem>
              <ListItemText 
                primary="No people added yet" 
                secondary="Add people to track their leave"
              />
            </ListItem>
          ) : (
            people.map((person) => (
              <ListItem 
                key={person.id}
                secondaryAction={
                  <Box>
                    <IconButton edge="end" aria-label="edit" onClick={() => handleEditClick(person, "person")}>
                      <EditIcon />
                    </IconButton>
                    <IconButton edge="end" aria-label="delete" onClick={() => handleDelete(person.id, "person")}>
                      <DeleteIcon />
                    </IconButton>
                  </Box>
                }
              >
                <ListItemText primary={person.name} />
              </ListItem>
            ))
          )}
        </List>
      </TabPanel>

      <TabPanel value={tabValue} index={1}>
        <Typography variant="h6" gutterBottom>
          Manage Leave Types
        </Typography>
        <Box sx={{ display: "flex", gap: 2, mb: 2 }}>
          <TextField
            label="Leave Type Name"
            value={newTypeName}
            onChange={(e) => setNewTypeName(e.target.value)}
            fullWidth
            placeholder="e.g., Annual Leave, Sick Leave"
            onKeyPress={(e) => e.key === "Enter" && handleAddType()}
          />
          <Button variant="contained" onClick={handleAddType}>
            Add
          </Button>
        </Box>
        <Divider sx={{ my: 2 }} />
        <Typography variant="subtitle2" color="text.secondary" gutterBottom>
          {types.length} {types.length === 1 ? "type" : "types"}
        </Typography>
        <List>
          {types.length === 0 ? (
            <ListItem>
              <ListItemText 
                primary="No leave types added yet" 
                secondary="Add leave types like Annual Leave, Sick Leave, etc."
              />
            </ListItem>
          ) : (
            types.map((type) => (
              <ListItem 
                key={type.id}
                secondaryAction={
                  <Box>
                    <IconButton edge="end" aria-label="edit" onClick={() => handleEditClick(type, "type")}>
                      <EditIcon />
                    </IconButton>
                    <IconButton edge="end" aria-label="delete" onClick={() => handleDelete(type.id, "type")}>
                      <DeleteIcon />
                    </IconButton>
                  </Box>
                }
              >
                <ListItemText primary={type.name} />
              </ListItem>
            ))
          )}
        </List>
      </TabPanel>

      <TabPanel value={tabValue} index={2}>
        <Typography variant="h6" gutterBottom>
          AI Instructions for Smart Identification
        </Typography>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Customize how the AI interprets chat conversations when extracting leave information.
          These instructions control what gets detected and how it's categorized.
        </Typography>
        
        {aiError && (
          <Alert severity="error" sx={{ mb: 2 }} onClose={() => setAiError("")}>
            {aiError}
          </Alert>
        )}
        
        {aiSuccess && (
          <Alert severity="success" sx={{ mb: 2 }}>
            AI instructions saved successfully!
          </Alert>
        )}

        <TextField
          multiline
          rows={15}
          fullWidth
          value={aiInstructionsText}
          onChange={(e) => setAiInstructionsText(e.target.value)}
          placeholder="Enter AI instructions..."
          sx={{ 
            mb: 2,
            fontFamily: 'monospace',
            '& textarea': {
              fontFamily: 'monospace',
              fontSize: '13px',
            }
          }}
        />
        
        <Box sx={{ display: "flex", gap: 2, justifyContent: "space-between" }}>
          <Button
            variant="outlined"
            startIcon={<RestoreIcon />}
            onClick={handleResetAiInstructions}
            disabled={aiLoading}
          >
            Reset to Default
          </Button>
          <Button
            variant="contained"
            onClick={handleSaveAiInstructions}
            disabled={aiLoading}
          >
            {aiLoading ? <CircularProgress size={24} /> : "Save Instructions"}
          </Button>
        </Box>
        
        {aiInstructions && (
          <Typography variant="caption" color="text.secondary" sx={{ mt: 2, display: "block" }}>
            Last updated: {new Date(aiInstructions.updated_at).toLocaleString()}
          </Typography>
        )}
      </TabPanel>

      {/* Edit Dialog */}
      <Dialog open={editDialogOpen} onClose={() => setEditDialogOpen(false)}>
        <DialogTitle>Edit {editType === "person" ? "Person" : "Leave Type"}</DialogTitle>
        <DialogContent>
          <TextField
            autoFocus
            margin="dense"
            label="Name"
            type="text"
            fullWidth
            value={editName}
            onChange={(e) => setEditName(e.target.value)}
            onKeyPress={(e) => e.key === "Enter" && handleEditSave()}
          />
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditDialogOpen(false)}>Cancel</Button>
          <Button onClick={handleEditSave} variant="contained">Save</Button>
        </DialogActions>
      </Dialog>
      </Card>
    </Box>
  );
}
