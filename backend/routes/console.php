<?php

use Illuminate\Support\Facades\Schedule;

// Full horizon every 15 minutes. Vendors revise times, so a tight sweep of the next
// two hours runs every minute as well; it's cheap and it's where the money is.
// The two share one mutex: both writing the same new vendor row would collide.
Schedule::command('calendar:sync')->everyFifteenMinutes()->name('calendar-sync')->withoutOverlapping();
Schedule::command('calendar:sync --hours=2')->everyMinute()->name('calendar-sync')->withoutOverlapping();

// Rungs whose queue job went missing get dispatched again.
Schedule::command('ladder:sweep')->everyMinute()->withoutOverlapping();

// Nightly sweep so every user's next 48 hours is scheduled even if nothing changed.
Schedule::command('ladder:reconcile')->dailyAt('00:30')->timezone('UTC');

// Housekeeping after the nightly sweep.
Schedule::command('guard:prune')->dailyAt('01:00')->timezone('UTC');
