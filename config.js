// =====================================================================
//  Wedding details + Supabase connection.
//  This is the ONLY file you need to edit. Everything else reads from it.
// =====================================================================

window.WEDDING = {
  // --- The couple & the day -------------------------------------------
  couple:        "Alex & Jordan",
  date:          "2027-04-17",            // YYYY-MM-DD
  dateDisplay:   "Saturday, 17 April 2027",
  ceremonyTime:  "15:00",
  receptionTime: "Reception to follow",
  venueName:     "The Venue Name",
  venueAddress:  "123 Example Road, Stellenbosch, 7600",
  mapsUrl:       "https://maps.google.com/?q=Stellenbosch",
  dressCode:     "Garden formal",
  rsvpDeadline:  "2027-02-28",             // YYYY-MM-DD — form closes after this day
  rsvpDeadlineDisplay: "28 February 2027",
  contactName:   "Alex",
  contactPhone:  "+27 82 000 0000",        // shown if guests have trouble
  extraNote:     "Kindly note that the venue is a short drive outside town — shuttle details to follow.",

  // --- Supabase (Project Settings → API) ------------------------------
  // Leave both empty to run in demo mode with sample guests.
  supabaseUrl:   "",                       // e.g. "https://abcdxyz.supabase.co"
  supabaseKey:   "",                       // the "anon public" / publishable key — NEVER the service_role / secret key
};
