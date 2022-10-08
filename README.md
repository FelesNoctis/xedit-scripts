# xedit-scripts
A  general repository of scripts I've made myself, worked on with others, or were made for me.

## 00_Persistentify_Those_Plugins.pas

- **Applies persistence to prevent breakage of references when converting a plugin file (.esp) to a master (.esm/ESM flag).**
- ***Modders' Resource** intended to emulate best practices Creation Kit behavior, but can also be run by any user to convert a plugin.*

**NEXUS:** https://www.nexusmods.com/skyrimspecialedition/mods/76750

Designed to be a more intelligent implementation than its predecessor, the "[ESMifyer](https://www.nexusmods.com/skyrimspecialedition/mods/40260)", which took a blanket approach to how it handled actor references (and only actor references). While that approach did keep affected actors functional, it also dramatically lessened the impact of what converting a plugin to a master is intended to accomplish.

The "Persistentifyer" (name may change) not only targets all relevant reference types that may need to be updated (currently ACHR/REFR/PHZD), but also uses a number of filters to cut out every false positive it can conceivably target without live human intervention. This list of filters continues to grow as we discover more edge cases in the various mods we test.

### Credits

- **FelesNoctis:** https://www.nexusmods.com/users/336042  
Framework, basic implementation of ACHR handling, logging and cleanup
- **Eddoursul:** https://eddoursul.win/  
Overhaul of functionality to include all important reference types, CK behavior research, and filter implementation
- **Robertgk2017, JonathanOstrus, Zilav**  
Critique of filters and optimization suggestions, extensive testing and suggestions, general moral boosting