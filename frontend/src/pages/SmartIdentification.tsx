import { useState, useEffect } from "react";
import {
  Card,
  Typography,
  TextField,
  Button,
  Box,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  Alert,
  CircularProgress,
  FormControl,
  Select,
  MenuItem,
} from "@mui/material";
import { smartIdentificationApi, peopleApi, typesApi, absencesApi } from "@services/api";
import type { ParsedLeaveEntry, Person, LeaveType } from "@services/api";

export default function SmartIdentification() {
  const [conversation, setConversation] = useState("");
  const [parsedEntries, setParsedEntries] = useState<ParsedLeaveEntry[]>([]);
  const [analysis, setAnalysis] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [apiHealth, setApiHealth] = useState<any>(null);
  
  // For mapping parsed entries to actual database entries
  const [people, setPeople] = useState<Person[]>([]);
  const [leaveTypes, setLeaveTypes] = useState<LeaveType[]>([]);
  const [selectedMappings, setSelectedMappings] = useState<{[key: number]: {personId: number, typeId: number, duration: string}}>({});

  useEffect(() => {
    checkApiHealth();
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const [peopleData, typesData] = await Promise.all([
        peopleApi.getAll(),
        typesApi.getAll()
      ]);
      setPeople(peopleData);
      setLeaveTypes(typesData);
    } catch (err) {
      console.error("Failed to fetch data:", err);
    }
  };

  const checkApiHealth = async () => {
    try {
      const health = await smartIdentificationApi.checkHealth();
      setApiHealth(health);
      if (health.status === "error") {
        setError(health.message);
      }
    } catch (err: any) {
      setError("Failed to check API health: " + err.message);
    }
  };

  const handleAnalyze = async () => {
    if (!conversation.trim()) {
      setError("Please paste a conversation to analyze");
      return;
    }

    setLoading(true);
    setError("");
    setSuccess("");
    setParsedEntries([]);
    setAnalysis("");

    try {
      const response = await smartIdentificationApi.analyze({ conversation });
      setParsedEntries(response.entries);
      setAnalysis(response.raw_analysis);
      
      // Initialize mappings with best guesses
      const initialMappings: {[key: number]: {personId: number, typeId: number, duration: string}} = {};
      response.entries.forEach((entry, index) => {
        // Try to find matching person
        const matchedPerson = people.find(p => 
          p.name.toLowerCase().includes(entry.person_name.toLowerCase()) ||
          entry.person_name.toLowerCase().includes(p.name.toLowerCase())
        );
        
        // Try to find matching leave type
        const matchedType = leaveTypes.find(t => 
          t.name.toLowerCase().includes(entry.leave_type.toLowerCase()) ||
          entry.leave_type.toLowerCase().includes(t.name.toLowerCase())
        );
        
        initialMappings[index] = {
          personId: matchedPerson?.id || 0,
          typeId: matchedType?.id || 0,
          duration: "Full Day"
        };
      });
      setSelectedMappings(initialMappings);
      
      setSuccess(`Found ${response.entries.length} leave request(s) in the conversation`);
    } catch (err: any) {
      setError(err.response?.data?.detail || "Failed to analyze conversation");
    } finally {
      setLoading(false);
    }
  };

  // Helper function to convert MM/DD/YYYY to YYYY-MM-DD
  const convertDateFormat = (dateStr: string): string => {
    try {
      // Handle MM/DD/YYYY format
      const parts = dateStr.split('/');
      if (parts.length === 3) {
        const [month, day, year] = parts;
        return `${year}-${month.padStart(2, '0')}-${day.padStart(2, '0')}`;
      }
      // If already in YYYY-MM-DD format, return as is
      return dateStr;
    } catch (err) {
      console.error("Date conversion error:", err);
      return dateStr;
    }
  };

  const handleSaveEntry = async (entry: ParsedLeaveEntry, index: number) => {
    const mapping = selectedMappings[index];
    if (!mapping || !mapping.personId || !mapping.typeId) {
      setError(`Please select a person and leave type for ${entry.person_name}`);
      return;
    }

    try {
      const formattedDate = convertDateFormat(entry.date);
      await absencesApi.create({
        person_id: mapping.personId,
        type_id: mapping.typeId,
        date: formattedDate,
        duration: mapping.duration,
        reason: entry.reason,
      });
      
      setSuccess(`Saved leave request for ${entry.person_name}`);
      
      // Remove the saved entry from the list
      setParsedEntries(prev => prev.filter((_, i) => i !== index));
    } catch (err: any) {
      setError(`Failed to save: ${err.response?.data?.detail || err.message}`);
    }
  };

  const handleSaveAll = async () => {
    let saved = 0;
    let failed = 0;

    for (let i = 0; i < parsedEntries.length; i++) {
      const entry = parsedEntries[i];
      const mapping = selectedMappings[i];
      
      if (!mapping || !mapping.personId || !mapping.typeId) {
        failed++;
        continue;
      }

      try {
        const formattedDate = convertDateFormat(entry.date);
        await absencesApi.create({
          person_id: mapping.personId,
          type_id: mapping.typeId,
          date: formattedDate,
          duration: mapping.duration,
          reason: entry.reason,
        });
        saved++;
      } catch (err) {
        failed++;
        console.error("Save error:", err);
      }
    }

    if (saved > 0) {
      setSuccess(`Successfully saved ${saved} leave request(s)`);
      setParsedEntries([]);
      setSelectedMappings({});
    }
    if (failed > 0) {
      setError(`Failed to save ${failed} entry(ies). Please check the mappings.`);
    }
  };

  const updateMapping = (index: number, field: 'personId' | 'typeId' | 'duration', value: any) => {
    setSelectedMappings(prev => ({
      ...prev,
      [index]: {
        ...prev[index],
        [field]: value
      }
    }));
  };

  const getConfidenceColor = (confidence: string) => {
    switch (confidence.toLowerCase()) {
      case "high": return "success";
      case "medium": return "warning";
      case "low": return "error";
      default: return "default";
    }
  };

  const exampleConversation = `[11:51 AM, 10/31/2025] Charif Seb: Good morning 
Not feeling well 
Will rest for the rest of the day / go to clinic
[12:02 PM, 10/31/2025] Sivabalan: Gws
[12:07 PM, 10/31/2025] Sanjeewa Rajapakshe: Gws
[12:07 PM, 10/31/2025] BoonLoong: Gws
[12:09 PM, 10/31/2025] Oliver Seb: gws
[12:55 PM, 10/31/2025] Jonathan Aka Jon Baltic: Gws
[1:56 PM, 10/31/2025] Charif Seb: Thanks`;

  return (
    <Box sx={{ p: { xs: 2, sm: 3, md: 4 } }}>
      <Typography variant="h4" sx={{ mb: 3 }}>
        Smart Identification
      </Typography>
      
      {apiHealth && apiHealth.status === "error" && (
        <Alert severity="error" sx={{ mb: 2 }}>
          {apiHealth.message}
        </Alert>
      )}
      
      {apiHealth && apiHealth.status === "success" && (
        <Alert severity="success" sx={{ mb: 2 }}>
          ✓ AI Engine Ready: {apiHealth.model}
        </Alert>
      )}

      <Card sx={{ p: { xs: 2, sm: 3 }, mb: 3 }}>
        <Typography variant="h6" sx={{ mb: 2 }}>
          Paste Chat Conversation
        </Typography>
        
        <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
          Paste WhatsApp or similar chat conversations where people announce their leave. 
          The AI will automatically identify who is taking leave, the type, and the date.
        </Typography>

        <Button 
          size="small" 
          onClick={() => setConversation(exampleConversation)}
          sx={{ mb: 2 }}
        >
          Load Example
        </Button>

        <TextField
          multiline
          rows={10}
          fullWidth
          placeholder="Paste your chat conversation here..."
          value={conversation}
          onChange={(e) => setConversation(e.target.value)}
          sx={{ mb: 2 }}
        />

        <Button
          variant="contained"
          onClick={handleAnalyze}
          disabled={loading || !conversation.trim()}
          fullWidth
        >
          {loading ? <CircularProgress size={24} /> : "Analyze Conversation"}
        </Button>
      </Card>

      {error && (
        <Alert severity="error" sx={{ mb: 2 }} onClose={() => setError("")}>
          {error}
        </Alert>
      )}

      {success && (
        <Alert severity="success" sx={{ mb: 2 }} onClose={() => setSuccess("")}>
          {success}
        </Alert>
      )}

      {analysis && (
        <Alert severity="info" sx={{ mb: 2 }}>
          <strong>AI Analysis:</strong> {analysis}
        </Alert>
      )}

      {parsedEntries.length > 0 && (
        <Card sx={{ p: { xs: 2, sm: 3 } }}>
          <Box sx={{ display: "flex", justifyContent: "space-between", alignItems: "center", mb: 2, flexWrap: "wrap", gap: 2 }}>
            <Typography variant="h6">
              Identified Leave Requests ({parsedEntries.length})
            </Typography>
            <Button
              variant="contained"
              color="primary"
              onClick={handleSaveAll}
              disabled={parsedEntries.length === 0}
              sx={{ minWidth: { xs: "100%", sm: "auto" } }}
            >
              Save All
            </Button>
          </Box>

          <TableContainer component={Paper} sx={{ overflowX: 'auto' }}>
            <Table>
              <TableHead>
                <TableRow>
                  <TableCell>Detected Name</TableCell>
                  <TableCell>Map to Person</TableCell>
                  <TableCell>Date</TableCell>
                  <TableCell>Detected Type</TableCell>
                  <TableCell>Map to Type</TableCell>
                  <TableCell>Duration</TableCell>
                  <TableCell>Reason</TableCell>
                  <TableCell>Confidence</TableCell>
                  <TableCell>Action</TableCell>
                </TableRow>
              </TableHead>
              <TableBody>
                {parsedEntries.map((entry, index) => (
                  <TableRow key={index}>
                    <TableCell>{entry.person_name}</TableCell>
                    <TableCell>
                      <FormControl size="small" fullWidth>
                        <Select
                          value={selectedMappings[index]?.personId || ""}
                          onChange={(e) => updateMapping(index, 'personId', e.target.value)}
                        >
                          <MenuItem value="">Select Person</MenuItem>
                          {people.map((person) => (
                            <MenuItem key={person.id} value={person.id}>
                              {person.name}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    </TableCell>
                    <TableCell>{entry.date}</TableCell>
                    <TableCell>{entry.leave_type}</TableCell>
                    <TableCell>
                      <FormControl size="small" fullWidth>
                        <Select
                          value={selectedMappings[index]?.typeId || ""}
                          onChange={(e) => updateMapping(index, 'typeId', e.target.value)}
                        >
                          <MenuItem value="">Select Type</MenuItem>
                          {leaveTypes.map((type) => (
                            <MenuItem key={type.id} value={type.id}>
                              {type.name}
                            </MenuItem>
                          ))}
                        </Select>
                      </FormControl>
                    </TableCell>
                    <TableCell>
                      <FormControl size="small" fullWidth>
                        <Select
                          value={selectedMappings[index]?.duration || "Full Day"}
                          onChange={(e) => updateMapping(index, 'duration', e.target.value)}
                        >
                          <MenuItem value="Full Day">Full Day</MenuItem>
                          <MenuItem value="First Half">First Half</MenuItem>
                          <MenuItem value="Second Half">Second Half</MenuItem>
                        </Select>
                      </FormControl>
                    </TableCell>
                    <TableCell sx={{ maxWidth: 200, overflow: "hidden", textOverflow: "ellipsis" }}>
                      {entry.reason}
                    </TableCell>
                    <TableCell>
                      <Chip
                        label={entry.confidence}
                        color={getConfidenceColor(entry.confidence) as any}
                        size="small"
                      />
                    </TableCell>
                    <TableCell>
                      <Button
                        size="small"
                        variant="outlined"
                        onClick={() => handleSaveEntry(entry, index)}
                      >
                        Save
                      </Button>
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          </TableContainer>
        </Card>
      )}
    </Box>
  );
}
