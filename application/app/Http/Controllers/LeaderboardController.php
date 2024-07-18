<?php

namespace App\Http\Controllers;

use Illuminate\Support\Facades\Storage;
use Illuminate\Http\Request;
use App\Models\Leaderboard;


class LeaderboardController extends Controller
{
    public function store(Request $request)
    {
        $request->validate([
            'username' => 'required|string|max:255',
            'score' => 'required|integer',
            'image' => 'nullable|image|mimes:jpeg,png,jpg,gif,svg|max:2048',
        ]);

        $path = null;
        if ($request->hasFile('image')) {
            $path = $request->file('image')->store('images', 's3');
            $url = Storage::disk('s3')->url($path);
        }

        $leaderboard = new Leaderboard();
        $leaderboard->username = $request->username;
        $leaderboard->score = $request->score;
        $leaderboard->image_url = $url ?? null;
        $leaderboard->save();

        return response()->json($leaderboard, 201);
    }
    public function destroy($id)
    {
        $leaderboard = Leaderboard::findOrFail($id);
        if ($leaderboard->image_url) {
            $path = parse_url($leaderboard->image_url, PHP_URL_PATH);
            Storage::disk('s3')->delete($path);
        }
        $leaderboard->delete();

        return response()->json(null, 204);
    }
}
