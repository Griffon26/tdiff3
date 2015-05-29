module termkey;

import core.stdc.config;

extern (C):

const int TERMKEY_VERSION_MAJOR = 0;
const int TERMKEY_VERSION_MINOR = 17;

void TERMKEY_CHECK_VERSION()
{
    termkey_check_version(TERMKEY_VERSION_MAJOR, TERMKEY_VERSION_MINOR);
}

enum TermKeySym {
  UNKNOWN = -1,
  NONE = 0,

  /* Special names in C0 */
  BACKSPACE,
  TAB,
  ENTER,
  ESCAPE,

  /* Special names in G0 */
  SPACE,
  DEL,

  /* Special keys */
  UP,
  DOWN,
  LEFT,
  RIGHT,
  BEGIN,
  FIND,
  INSERT,
  DELETE,
  SELECT,
  PAGEUP,
  PAGEDOWN,
  HOME,
  END,

  /* Special keys from terminfo */
  CANCEL,
  CLEAR,
  CLOSE,
  COMMAND,
  COPY,
  EXIT,
  HELP,
  MARK,
  MESSAGE,
  MOVE,
  OPEN,
  OPTIONS,
  PRINT,
  REDO,
  REFERENCE,
  REFRESH,
  REPLACE,
  RESTART,
  RESUME,
  SAVE,
  SUSPEND,
  UNDO,

  /* Numeric keypad special keys */
  KP0,
  KP1,
  KP2,
  KP3,
  KP4,
  KP5,
  KP6,
  KP7,
  KP8,
  KP9,
  KPENTER,
  KPPLUS,
  KPMINUS,
  KPMULT,
  KPDIV,
  KPCOMMA,
  KPPERIOD,
  KPEQUALS,

  /* et cetera ad nauseum */
  N_SYMS
}

enum TermKeyType {
  UNICODE,
  FUNCTION,
  KEYSYM,
  MOUSE,
  POSITION,
  MODEREPORT,
  /* add other recognised types here */

  UNKNOWN_CSI = -1
}

enum TermKeyResult {
  NONE,
  KEY,
  EOF,
  AGAIN,
  ERROR
}

enum TermKeyMouseEvent {
  UNKNOWN,
  PRESS,
  DRAG,
  RELEASE
}

enum TermKeyKeyMod {
  SHIFT = 1 << 0,
  ALT   = 1 << 1,
  CTRL  = 1 << 2
}

union _TermKeyCode {
  c_long     codepoint; /* TERMKEY_TYPE_UNICODE */
  int        number;    /* TERMKEY_TYPE_FUNCTION */
  TermKeySym sym;       /* TERMKEY_TYPE_KEYSYM */
  char[4]    mouse;     /* TERMKEY_TYPE_MOUSE */
                          /* opaque. see termkey_interpret_mouse */
}

struct TermKeyKey {
  TermKeyType type;

  _TermKeyCode code;

  int modifiers;

  /* Any Unicode character can be UTF-8 encoded in no more than 6 bytes, plus
   * terminating NUL */
  char[7] utf8;
}

struct TermKey;

enum TermKeyFlag {
  NOINTERPRET = 1 << 0, /* Do not interpret C0//DEL codes if possible */
  CONVERTKP   = 1 << 1, /* Convert KP codes to regular keypresses */
  RAW         = 1 << 2, /* Input is raw bytes, not UTF-8 */
  UTF8        = 1 << 3, /* Input is definitely UTF-8 */
  NOTERMIOS   = 1 << 4, /* Do not make initial termios calls on construction */
  SPACESYMBOL = 1 << 5, /* Sets TERMKEY_CANON_SPACESYMBOL */
  CTRLC       = 1 << 6, /* Allow Ctrl-C to be read as normal, disabling SIGINT */
  EINTR       = 1 << 7  /* Return ERROR on signal (EINTR) rather than retry */
}

enum TermKeyCanon {
  SPACESYMBOL = 1 << 0, /* Space is symbolic rather than Unicode */
  DELBS       = 1 << 1  /* Del is converted to Backspace */
}

void termkey_check_version(int major, int minor);

TermKey *termkey_new(int fd, int flags);
TermKey *termkey_new_abstract(const char *term, int flags);
void     termkey_free(TermKey *tk);
void     termkey_destroy(TermKey *tk);

int termkey_start(TermKey *tk);
int termkey_stop(TermKey *tk);
int termkey_is_started(TermKey *tk);

int termkey_get_fd(TermKey *tk);

int  termkey_get_flags(TermKey *tk);
void termkey_set_flags(TermKey *tk, int newflags);

int  termkey_get_waittime(TermKey *tk);
void termkey_set_waittime(TermKey *tk, int msec);

int  termkey_get_canonflags(TermKey *tk);
void termkey_set_canonflags(TermKey *tk, int);

size_t termkey_get_buffer_size(TermKey *tk);
int    termkey_set_buffer_size(TermKey *tk, size_t size);

size_t termkey_get_buffer_remaining(TermKey *tk);

void termkey_canonicalise(TermKey *tk, TermKeyKey *key);

TermKeyResult termkey_getkey(TermKey *tk, TermKeyKey *key);
TermKeyResult termkey_getkey_force(TermKey *tk, TermKeyKey *key);
TermKeyResult termkey_waitkey(TermKey *tk, TermKeyKey *key);

TermKeyResult termkey_advisereadable(TermKey *tk);

size_t termkey_push_bytes(TermKey *tk, const char *bytes, size_t len);

TermKeySym termkey_register_keyname(TermKey *tk, TermKeySym sym, const char *name);
const(char *) termkey_get_keyname(TermKey *tk, TermKeySym sym);
const(char *) termkey_lookup_keyname(TermKey *tk, const char *str, TermKeySym *sym);

TermKeySym termkey_keyname2sym(TermKey *tk, const char *keyname);

TermKeyResult termkey_interpret_mouse(TermKey *tk, const TermKeyKey *key, TermKeyMouseEvent *event, int *button, int *line, int *col);

TermKeyResult termkey_interpret_position(TermKey *tk, const TermKeyKey *key, int *line, int *col);

TermKeyResult termkey_interpret_modereport(TermKey *tk, const TermKeyKey *key, int *initial, int *mode, int *value);

TermKeyResult termkey_interpret_csi(TermKey *tk, const TermKeyKey *key, c_long *args, size_t *nargs, c_ulong *cmd);

enum TermKeyFormat {
  LONGMOD     = 1 << 0, /* Shift-... instead of S-... */
  CARETCTRL   = 1 << 1, /* ^X instead of C-X */
  ALTISMETA   = 1 << 2, /* Meta- or M- instead of Alt- or A- */
  WRAPBRACKET = 1 << 3, /* Wrap special keys in brackets like <Escape> */
  SPACEMOD    = 1 << 4, /* M Foo instead of M-Foo */
  LOWERMOD    = 1 << 5, /* meta or m instead of Meta or M */
  LOWERSPACE  = 1 << 6, /* page down instead of PageDown */

  MOUSE_POS   = 1 << 8,  /* Include mouse position if relevant; @ col,line */

  VIM = (ALTISMETA | WRAPBRACKET),
  URWID = (LONGMOD|ALTISMETA|LOWERMOD|SPACEMOD|LOWERSPACE)
}

/* Some useful combinations */

const uint TERMKEY_FORMAT_VIM = (TermKeyFormat.ALTISMETA|TermKeyFormat.WRAPBRACKET);
const uint TERMKEY_FORMAT_URWID = (TermKeyFormat.LONGMOD|TermKeyFormat.ALTISMETA|
          TermKeyFormat.LOWERMOD|TermKeyFormat.SPACEMOD|TermKeyFormat.LOWERSPACE);

size_t      termkey_strfkey(TermKey *tk, char *buffer, size_t len, TermKeyKey *key, TermKeyFormat format);
const(char *) termkey_strpkey(TermKey *tk, const char *str, TermKeyKey *key, TermKeyFormat format);

int termkey_keycmp(TermKey *tk, const TermKeyKey *key1, const TermKeyKey *key2);

