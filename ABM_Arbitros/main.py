import re
import tkinter as tk
from tkinter import ttk, messagebox
import pyodbc

# ==========================================
# CONFIGURACIÓN DE CONEXIÓN Y CIFRADO
# ==========================================
SERVER = "127.0.0.1,1433"
DATABASE = "GestionDelMundial"
USERNAME = "login_gestor_fifa"
PASSWORD = "PasswordGestor123!"

# Frase de cifrado definida en Cifrado.sql
PASSPHRASE = "QuieroMiPanDanes"


def obtener_driver():
    """Detecta automáticamente el driver ODBC de SQL Server instalado en Windows."""
    drivers = [d for d in pyodbc.drivers() if "SQL Server" in d]
    for preferido in ["ODBC Driver 18 for SQL Server", "ODBC Driver 17 for SQL Server", "SQL Server"]:
        if preferido in drivers:
            return preferido
    return drivers[0] if drivers else "ODBC Driver 17 for SQL Server"


def conectar():
    driver = obtener_driver()
    conn_str = (
        f"DRIVER={{{driver}}};"
        f"SERVER={SERVER};"
        f"DATABASE={DATABASE};"
        f"UID={USERNAME};"
        f"PWD={PASSWORD};"
        "TrustServerCertificate=yes;"
    )
    return pyodbc.connect(conn_str, autocommit=True)


def limpiar_error_sql(err):
    """Extrae el mensaje limpio lanzado por THROW 50001 en SQL Server."""
    texto = str(err)
    match = re.search(r"\[SQL Server\](.+?)(?:\(\d+\)|$)", texto, re.DOTALL)
    return match.group(1).strip() if match else texto


# ==========================================
# INTERFAZ GRÁFICA (TKINTER)
# ==========================================
class AppArbitros:
    def __init__(self, root):
        self.root = root
        self.root.title("Gestión de Árbitros - Mundial FIFA (ABM)")
        self.root.geometry("820x590")
        self.root.resizable(False, False)

        self.paises_map = {}         # "ARG - Argentina" -> "ARG"
        self.confederaciones_map = {"(Ninguna)": None}
        self.var_cifrado = tk.BooleanVar(value=False)

        self._construir_ui()
        self._cargar_combos()
        self._cargar_tabla()

    def _construir_ui(self):
        # --- Selector de Modo (Sin cifrar / Cifrado) ---
        frame_modo = ttk.LabelFrame(self.root, text="Modo de Lectura en Base de Datos", padding=8)
        frame_modo.pack(fill="x", padx=12, pady=(8, 4))

        ttk.Radiobutton(
            frame_modo,
            text="Sin cifrar (columna apellido)",
            variable=self.var_cifrado,
            value=False,
            command=self._cargar_tabla,
        ).pack(side="left", padx=10)

        ttk.Radiobutton(
            frame_modo,
            text="Cifrado (DecryptByPassPhrase sobre apellido_cifrado)",
            variable=self.var_cifrado,
            value=True,
            command=self._cargar_tabla,
        ).pack(side="left", padx=10)

        ttk.Button(frame_modo, text="Refrescar lista", command=self._cargar_tabla).pack(side="right", padx=5)

        # --- Formulario ---
        frame_form = ttk.LabelFrame(self.root, text="Datos del Árbitro", padding=10)
        frame_form.pack(fill="x", padx=12, pady=6)

        ttk.Label(frame_form, text="ID:").grid(row=0, column=0, sticky="w", padx=5, pady=4)
        self.var_id = tk.StringVar()
        ttk.Entry(frame_form, textvariable=self.var_id, state="readonly", width=10).grid(row=0, column=1, sticky="w", padx=5)

        ttk.Label(frame_form, text="País:").grid(row=0, column=2, sticky="w", padx=5, pady=4)
        self.combo_pais = ttk.Combobox(frame_form, state="readonly", width=28)
        self.combo_pais.grid(row=0, column=3, sticky="w", padx=5)

        ttk.Label(frame_form, text="Confederación:").grid(row=0, column=4, sticky="w", padx=5, pady=4)
        self.combo_conf = ttk.Combobox(frame_form, state="readonly", width=18)
        self.combo_conf.grid(row=0, column=5, sticky="w", padx=5)

        ttk.Label(frame_form, text="Nombre:").grid(row=1, column=0, sticky="w", padx=5, pady=4)
        self.var_nombre = tk.StringVar()
        ttk.Entry(frame_form, textvariable=self.var_nombre, width=25).grid(row=1, column=1, columnspan=2, sticky="w", padx=5)

        ttk.Label(frame_form, text="Apellido:").grid(row=1, column=3, sticky="w", padx=5, pady=4)
        self.var_apellido = tk.StringVar()
        ttk.Entry(frame_form, textvariable=self.var_apellido, width=25).grid(row=1, column=4, sticky="w", padx=5)

        self.var_es_mujer = tk.BooleanVar(value=False)
        self.chk_mujer = ttk.Checkbutton(frame_form, text="Es Mujer", variable=self.var_es_mujer)
        self.chk_mujer.grid(row=1, column=5, sticky="w", padx=5)

        # --- Botones ABM ---
        frame_btns = ttk.Frame(self.root, padding=5)
        frame_btns.pack(fill="x", padx=12)

        ttk.Button(frame_btns, text="Crear (Alta)", command=self.crear_arbitro).pack(side="left", padx=5)
        ttk.Button(frame_btns, text="Modificar", command=self.modificar_arbitro).pack(side="left", padx=5)
        ttk.Button(frame_btns, text="Eliminar (Baja)", command=self.eliminar_arbitro).pack(side="left", padx=5)
        ttk.Button(frame_btns, text="Limpiar / Nuevo", command=self.limpiar_formulario).pack(side="right", padx=5)

        # --- Tabla ---
        frame_tabla = ttk.Frame(self.root, padding=10)
        frame_tabla.pack(fill="both", expand=True, padx=12, pady=4)

        cols = ("id", "pais", "nombre", "apellido", "genero", "confederacion")
        self.tree = ttk.Treeview(frame_tabla, columns=cols, show="headings", height=15)

        encabezados = {
            "id": ("ID", 50),
            "pais": ("País", 80),
            "nombre": ("Nombre", 180),
            "apellido": ("Apellido", 180),
            "genero": ("Género", 100),
            "confederacion": ("Confederación", 150),
        }
        for col, (texto, ancho) in encabezados.items():
            self.tree.heading(col, text=texto)
            self.tree.column(col, width=ancho, anchor="center" if col in ("id", "pais", "genero") else "w")

        scroll = ttk.Scrollbar(frame_tabla, orient="vertical", command=self.tree.yview)
        self.tree.configure(yscrollcommand=scroll.set)

        self.tree.pack(side="left", fill="both", expand=True)
        scroll.pack(side="right", fill="y")
        self.tree.bind("<<TreeviewSelect>>", self.al_seleccionar_fila)

    def _cargar_combos(self):
        try:
            with conectar() as conn:
                cur = conn.cursor()
                cur.execute("SELECT codigo, nombre FROM Administracion.Paises ORDER BY nombre")
                for cod, nom in cur.fetchall():
                    etiqueta = f"{cod} - {nom}"
                    self.paises_map[etiqueta] = cod
                self.combo_pais["values"] = list(self.paises_map.keys())

                cur.execute("SELECT id, siglas FROM Administracion.Confederaciones ORDER BY siglas")
                for cid, siglas in cur.fetchall():
                    self.confederaciones_map[siglas] = cid
                self.combo_conf["values"] = list(self.confederaciones_map.keys())
                self.combo_conf.set("(Ninguna)")
        except Exception as e:
            messagebox.showerror("Error de conexión", limpiar_error_sql(e))

    def _cargar_tabla(self):
        for item in self.tree.get_children():
            self.tree.delete(item)

        try:
            with conectar() as conn:
                cur = conn.cursor()
                if self.var_cifrado.get():

                    query = """
                        SELECT 
                            A.id, 
                            A.pais_id, 
                            A.nombre, 
                            COALESCE(
                                CONVERT(VARCHAR(100), DecryptByPassPhrase(CAST(? AS NVARCHAR(50)), A.apellido_cifrado)),
                                CONVERT(VARCHAR(100), DecryptByPassPhrase(CAST(? AS VARCHAR(50)), A.apellido_cifrado))
                            ) AS apellido, 
                            A.es_mujer, 
                            ISNULL(C.siglas, '-')
                        FROM Arbitraje.Arbitros A
                        LEFT JOIN Administracion.Confederaciones C ON C.id = A.confederacion_id
                        ORDER BY A.id DESC;
                    """
                    cur.execute(query, (PASSPHRASE, PASSPHRASE))
                else:
                    query = """
                        SELECT 
                            A.id, 
                            A.pais_id, 
                            A.nombre, 
                            A.apellido, 
                            A.es_mujer, 
                            ISNULL(C.siglas, '-')
                        FROM Arbitraje.Arbitros A
                        LEFT JOIN Administracion.Confederaciones C ON C.id = A.confederacion_id
                        ORDER BY A.id DESC;
                    """
                    cur.execute(query)

                for row in cur.fetchall():
                    genero = "Femenino" if row[4] else "Masculino"
                    self.tree.insert("", "end", values=(row[0], row[1], row[2], row[3], genero, row[5]))
        except Exception as e:
            messagebox.showerror("Error al listar", limpiar_error_sql(e))

    def al_seleccionar_fila(self, _event):
        seleccion = self.tree.selection()
        if not seleccion:
            return
        vals = self.tree.item(seleccion[0], "values")
        self.var_id.set(vals[0])
        self.var_nombre.set(vals[2])
        self.var_apellido.set(vals[3])
        self.var_es_mujer.set(vals[4] == "Femenino")

        for k, v in self.paises_map.items():
            if v == vals[1]:
                self.combo_pais.set(k)
                break
        self.combo_conf.set(vals[5] if vals[5] != "-" else "(Ninguna)")

        self.combo_pais.config(state="disabled")
        self.combo_conf.config(state="disabled")
        self.chk_mujer.config(state="disabled")

    def limpiar_formulario(self):
        self.var_id.set("")
        self.var_nombre.set("")
        self.var_apellido.set("")
        self.var_es_mujer.set(False)
        self.combo_pais.set("")
        self.combo_conf.set("(Ninguna)")
        self.combo_pais.config(state="readonly")
        self.combo_conf.config(state="readonly")
        self.chk_mujer.config(state="normal")
        self.tree.selection_remove(self.tree.selection())

    def crear_arbitro(self):
        if self.var_id.get():
            messagebox.showwarning("Aviso", "Presioná 'Limpiar / Nuevo' antes de dar de alta un árbitro.")
            return

        codigo_pais = self.paises_map.get(self.combo_pais.get())
        nombre = self.var_nombre.get().strip() or None
        apellido = self.var_apellido.get().strip() or None
        es_mujer = 1 if self.var_es_mujer.get() else 0
        conf_id = self.confederaciones_map.get(self.combo_conf.get())

        try:
            with conectar() as conn:
                cur = conn.cursor()
                cur.execute(
                    "EXEC Arbitraje.sp_crear_arbitro @CodigoPais=?, @Nombre=?, @Apellido=?, @EsMujer=?, @ConfederacionID=?",
                    (codigo_pais, nombre, apellido, es_mujer, conf_id),
                )
            messagebox.showinfo("Éxito", "Árbitro registrado correctamente.")
            self.limpiar_formulario()
            self._cargar_tabla()
        except Exception as e:
            messagebox.showerror("Error de validación", limpiar_error_sql(e))

    def modificar_arbitro(self):
        if not self.var_id.get():
            messagebox.showwarning("Aviso", "Seleccioná un árbitro de la tabla para modificar.")
            return

        arbitro_id = int(self.var_id.get())
        nombre = self.var_nombre.get().strip() or None
        apellido = self.var_apellido.get().strip() or None

        try:
            with conectar() as conn:
                cur = conn.cursor()
                cur.execute(
                    "EXEC Arbitraje.sp_modificar_arbitro @ID=?, @Nombre=?, @Apellido=?",
                    (arbitro_id, nombre, apellido),
                )
            messagebox.showinfo("Éxito", "Árbitro actualizado correctamente.")
            self.limpiar_formulario()
            self._cargar_tabla()
        except Exception as e:
            messagebox.showerror("Error de validación", limpiar_error_sql(e))

    def eliminar_arbitro(self):
        if not self.var_id.get():
            messagebox.showwarning("Aviso", "Seleccioná un árbitro de la tabla para eliminar.")
            return

        arbitro_id = int(self.var_id.get())
        if not messagebox.askyesno("Confirmar baja", f"¿Eliminar al árbitro ID {arbitro_id}?"):
            return

        try:
            with conectar() as conn:
                cur = conn.cursor()
                cur.execute("EXEC Arbitraje.sp_eliminar_arbitro @ID=?", (arbitro_id,))
            messagebox.showinfo("Éxito", "Árbitro eliminado correctamente.")
            self.limpiar_formulario()
            self._cargar_tabla()
        except Exception as e:
            messagebox.showerror("No se puede eliminar", limpiar_error_sql(e))


if __name__ == "__main__":
    root = tk.Tk()
    AppArbitros(root)
    root.mainloop()