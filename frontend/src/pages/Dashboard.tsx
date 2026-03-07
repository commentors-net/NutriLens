import { useState, useEffect } from "react";
import { 
  TextField, 
  Button, 
  Card, 
  Typography, 
  Select, 
  MenuItem, 
  InputLabel, 
  FormControl,
  Box,
  Stack
} from "@mui/material";
import { peopleApi, typesApi, absencesApi } from "@services/api";
import type { Person, LeaveType } from "@services/api";

export default function Dashboard() {
  const [people, setPeople] = useState<Person[]>([]);
  const [types, setTypes] = useState<LeaveType[]>([]);
  const [selectedPerson, setSelectedPerson] = useState("");
  const [selectedType, setSelectedType] = useState("");
  const [date, setDate] = useState("");
  const [duration, setDuration] = useState("");
  const [reason, setReason] = useState("");

  useEffect(() => {
    const fetchData = async () => {
      try {
        const [peopleData, typesData] = await Promise.all([
          peopleApi.getAll(),
          typesApi.getAll()
        ]);
        setPeople(peopleData);
        setTypes(typesData);
      } catch (err) {
        console.error("Failed to fetch data:", err);
        alert("Failed to load data. Please login again.");
      }
    };
    fetchData();
  }, []);

  const handleSubmit = async () => {
    try {
      await absencesApi.create({
        person_id: Number(selectedPerson),
        type_id: Number(selectedType),
        date,
        duration,
        reason,
      });
      alert("Absence logged successfully!");
      
      // Clear the form
      setSelectedPerson("");
      setSelectedType("");
      setDate("");
      setDuration("");
      setReason("");
    } catch (err) {
      alert("Failed to log absence");
    }
  };

  return (
    <Box sx={{ maxWidth: 800, mx: "auto", mt: { xs: 2, sm: 4, md: 6 }, px: { xs: 2, sm: 3 } }}>
      <Card sx={{ p: { xs: 2, sm: 3, md: 4 } }}>
        <Typography variant="h5" sx={{ mb: 3 }}>Log Absence</Typography>
        <Stack spacing={2}>
          <Box sx={{ display: 'flex', gap: 2, flexDirection: { xs: 'column', sm: 'row' } }}>
            <FormControl fullWidth>
              <InputLabel>Person</InputLabel>
              <Select value={selectedPerson} onChange={(e) => setSelectedPerson(e.target.value)} label="Person">
                {people.map((person) => (
                  <MenuItem key={person.id} value={person.id}>{person.name}</MenuItem>
                ))}
              </Select>
            </FormControl>
            <TextField 
              type="date" 
              value={date} 
              onChange={(e) => setDate(e.target.value)} 
              fullWidth 
              label="Date"
              InputLabelProps={{ shrink: true }}
            />
          </Box>
          <Box sx={{ display: 'flex', gap: 2, flexDirection: { xs: 'column', sm: 'row' } }}>
            <FormControl fullWidth>
              <InputLabel>Duration</InputLabel>
              <Select value={duration} onChange={(e) => setDuration(e.target.value)} label="Duration">
                <MenuItem value="First Half">First Half</MenuItem>
                <MenuItem value="Second Half">Second Half</MenuItem>
                <MenuItem value="Full Day">Full Day</MenuItem>
              </Select>
            </FormControl>
            <FormControl fullWidth>
              <InputLabel>Type</InputLabel>
              <Select value={selectedType} onChange={(e) => setSelectedType(e.target.value)} label="Type">
                {types.map((type) => (
                  <MenuItem key={type.id} value={type.id}>{type.name}</MenuItem>
                ))}
              </Select>
            </FormControl>
          </Box>
          <TextField 
            label="Reason" 
            value={reason} 
            onChange={(e) => setReason(e.target.value)} 
            fullWidth 
            multiline 
            rows={3}
          />
          <Button variant="contained" fullWidth onClick={handleSubmit} size="large">
            Submit
          </Button>
        </Stack>
      </Card>
    </Box>
  );
}
