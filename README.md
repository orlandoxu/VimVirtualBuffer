# VimVirtualBuffer

```
A sorted buffer tabline.
You can change buffer's position of buffer tabline.
```

### How to install
```
Plug 'orlandoxu/VimVirtualBuffer'
```

### Go to left/right position
> Notice: u can't using :bd to switch buffer, alter with BufPrev & BufNext. Bacause vim's buffer num cannot change!
```
:BufPrev<CR>
:BufNext<CR>
```

### Move buffer left/right
```
:MoveBufLeft<CR>
:MoveBufRight<CR>
```
