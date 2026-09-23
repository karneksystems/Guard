<?php

use Illuminate\Support\Facades\Schedule;

// Full horizon every 15 minutes. Vendors revise times, so a tight sweep of the next
// two hours runs every minute as well; it's cheap and it's where the money is.
Schedule::command('calendar:sync')->everyFifteenMinutes()->withoutOverlapping();
Schedule::command('calendar:sync --hours=2')->everyMinute()->withoutOverlapping();

// Nightly sweep so every user's next 48 hours is scheduled even if nothing changed.
Schedule::command('ladder:reconcile')->dailyAt('00:30')->timezone('UTC');
