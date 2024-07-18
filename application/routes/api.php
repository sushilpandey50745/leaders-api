<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\LeaderboardController;

/*
|--------------------------------------------------------------------------
| API Routes
|--------------------------------------------------------------------------
|
| Here is where you can register API routes for your application. These
| routes are loaded by the RouteServiceProvider within a group which
| is assigned the "api" middleware group. Enjoy building your API!
|
*/

Route::middleware('auth:sanctum')->get('/user', function (Request $request) {
    return $request->user();
});


// Route::get('/leaders', function () {
//     return "Hello from api from another branch to see live changes";
// });

Route::get('/leaderboard', [LeaderboardController::class, 'index']);
Route::post('/leaderboard', [LeaderboardController::class, 'store']);
Route::delete('/leaderboard/{id}', [LeaderboardController::class, 'destroy']);

