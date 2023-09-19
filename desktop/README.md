`$HOME` in paths needs to be replaced by the actual path.  
Sed command for that:  
```bash
sed "s|\$HOME|$HOME|g" example.desktop > ~/.local/share/applications/example.desktop  
...
```

