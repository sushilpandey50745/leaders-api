<?php
namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;

class UserController extends Controller
{
    public function createUser(Request $request)
    {
        $request->validate([
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:8',
            'image' => 'required|image|mimes:jpeg,png,jpg,gif,svg|max:2048',
        ]);

        // Upload image to S3
        $imagePath = $request->file('image')->store('images', 's3');
        Storage::disk('s3')->setVisibility($imagePath, 'public');

        // Create user
        $user = User::create([
            'name' => $request->name,
            'email' => $request->email,
            'password' => bcrypt($request->password),
            'image' => Storage::disk('s3')->url($imagePath),
        ]);

        return response()->json($user);
    }

    public function deleteUser($id)
    {
        $user = User::findOrFail($id);
        if ($user->image) {
            $imagePath = parse_url($user->image, PHP_URL_PATH);
            Storage::disk('s3')->delete($imagePath);
        }
        $user->delete();

        return response()->json(['message' => 'User deleted successfully.']);
    }
}