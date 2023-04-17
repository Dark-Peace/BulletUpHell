# BulletupHell

 1. Presentation
 2. Installation
 3. Q&A
 
## Presentation

BulletUpHell is a BulletHell Godot plugin available for
 - Godot 3.4
 - Godot 3.5
 - Godot 4 (recommended version)

The goal is to provide you with all the tools you need to make a BulletHell game. The plugin takes care of everything related to bullet spawning : patterns, bullet properties, event triggering,... Features include complex bullet movement (from math equations to custom drawn paths), advanced homing features, built-in animation and sound manager, ability to randomise everything, and much more !

As a BulletHell dev myself, my aim is to create a plugin able to recreate ALL the attack patterns present in your favorite bullethell games. For that, I researched all of the attacks in games like Enter the Gungeon and Binding of Isaac and implemented the necessary features to recreate them all with easiness of use and flexibility in mind.

The plugin has 4 custom nodes and a bunch of resources you can use to create all the complex attack patterns without coding (but some things are just much more easier to do by code, I didn't make it with the goal that someone who doesn't know how to code could use it). Just drag and drop them in your scene, fill up the properties you want and watch as the magic happens.

![Godot_v4 0-stable_win64_kKgJZaEScg](https://user-images.githubusercontent.com/74102789/232424299-f37086cc-1e79-421f-a0b8-91a93c53f74e.gif)
![Godot_v4 0-stable_win64_9tcJjfETCc](https://user-images.githubusercontent.com/74102789/232424341-ead8e0e5-31b0-46b1-a679-71896bbf4e42.gif)
![Godot_v4 0-stable_win64_5Dstv76K6b](https://user-images.githubusercontent.com/74102789/232424373-27c334ba-47e1-4908-bb17-34a4a3ad02a0.gif)
![Godot_v4 0-stable_win64_LJrtOJvI9x](https://user-images.githubusercontent.com/74102789/232424433-88b62875-cf6f-4037-9fda-3159a450c333.gif)
![Godot_v4 0-stable_win64_O3nX5Jenfm](https://user-images.githubusercontent.com/74102789/232424505-621dc350-94d0-423b-8a09-1ed2408d7965.gif)


I also provide you with a full documentation on how to use everything. See next paragraph.

## Installation

Download the latest release from the Release section. For the rest of the installation and the documentation of all my plugins, check this : [BottledPluginsDocumentation](https://docs.google.com/document/d/1y2aPsn72dOxQ-wBNGqLlQvrw9-SV_z12a1MradBglF4/edit?usp=sharing)

I'll also post complete tutorials on my Youtube channel when I'll have the time so consider subscribing to not miss any news !
https://www.youtube.com/@Dark_Peace
For any question or request, join my Discord : https://discord.com/invite/aWWQbgQUEP

## Q&A

Q: Will there be new features in the future ?
A: Yes, you can read a barely readable checklist in the documentation. New features will be added in V4 for Godot 4. They'll most likely won't be backported to Godot 3.

Q: I downloaded the alpha version, should I change to V3.4 or V4.0 ? Are they compatible ?
A: If you're satisfied with the features and the performances of V0.1, there is no reason to update, as they're will probably be compatibility issues since I rewrote all the back-end of the plugin.

Q: Will V3.4 and V4 be compatible (aka : can I use V34 and update it later to V4 ?) ?
A: No major changes should occur in the way the plugin works. But using custom resources in Godot sometimes lead to issues when those resources update. The safest way is always to make a back-up before updating.

Q: Will the alpha version, with its unoptimised code, be updated Godot 4 ?
A: No. But someone contacted me to ask if they could, I said yes.

Q: Can I make updates to the plugin ?
A: Sure, but please tell me about it. Also any feature idea is welcomed.

Q: The alpha version used nodes as bullets, but not the V3.4/V4 and I don't like it.
A: It was for optimisation's sake. All of the basic features of a node are reproductible with the current system but I'll add node-compatibility in the V4 for Godot 4.
