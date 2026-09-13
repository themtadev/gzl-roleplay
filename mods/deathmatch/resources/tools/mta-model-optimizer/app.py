import tkinter as tk
from tkinter import ttk, filedialog, messagebox
from pathlib import Path
import sys, json, subprocess, shutil, threading, queue, math, datetime, os
BASE=Path(getattr(sys,'_MEIPASS',Path(__file__).resolve().parent))
PROFILES={'Hafif — hedef %15 azaltma':'light','Orta — hedef %35 azaltma':'medium','Güçlü — hedef %55 azaltma':'strong','Low-poly — hedef %75 azaltma':'lowpoly'}
class App(tk.Tk):
 def __init__(self):
  super().__init__();self.title('GZL • MTA Model Optimizer');self.geometry('1220x830');self.minsize(1000,700);self.configure(bg='#101722')
  self.files=[];self.before=None;self.after_result=None;self.busy=False;self.q=queue.Queue();self.angle=.6;self.zoom=1;self.drag=None
  style=ttk.Style(self);style.theme_use('clam');style.configure('.',background='#162131',foreground='#e5edf8',font=('Segoe UI',10));style.configure('TButton',padding=9);style.configure('Treeview',background='#101722',fieldbackground='#101722',rowheight=27);style.map('Treeview',background=[('selected','#345480')]);style.configure('TCombobox',fieldbackground='#25364d')
  header=tk.Frame(self,bg='#101722');header.pack(fill='x',padx=22,pady=16)
  tk.Label(header,text='MTA MODEL OPTIMIZER',font=('Segoe UI Semibold',23),fg='#8baeff',bg='#101722').pack(anchor='w')
  tk.Label(header,text='Statik DFF sadeleştirme • COL / TXD analizi • Orijinallerin üzerine yazılmaz',fg='#9aacbf',bg='#101722').pack(anchor='w')
  controls=ttk.Frame(self);controls.pack(fill='x',padx=22)
  ttk.Button(controls,text='Dosya ekle',command=self.add).pack(side='left',padx=4)
  ttk.Button(controls,text='Listeyi temizle',command=self.clear).pack(side='left',padx=4)
  self.profile=tk.StringVar(value=list(PROFILES)[1]);ttk.Combobox(controls,textvariable=self.profile,values=list(PROFILES),state='readonly',width=33).pack(side='left',padx=8)
  ttk.Button(controls,text='Seçileni analiz et',command=self.analyze).pack(side='left',padx=4)
  ttk.Button(controls,text='Seçilenleri dışa aktar',command=self.optimize).pack(side='left',padx=4)
  self.table=ttk.Treeview(self,columns=('type','size','state'),show='tree headings',height=5,selectmode='extended');self.table.heading('#0',text='DOSYA');self.table.heading('type',text='TÜR');self.table.heading('size',text='BOYUT');self.table.heading('state',text='SONUÇ');self.table.column('#0',width=410);self.table.column('type',width=65);self.table.column('size',width=110);self.table.column('state',width=400);self.table.pack(fill='x',padx=22,pady=12)
  self.stats=tk.StringVar(value='Bir DFF seçerek başlayın. Hafif / orta / güçlü / low-poly profilleri hedef oranlardır.')
  ttk.Label(self,textvariable=self.stats,font=('Segoe UI Semibold',12)).pack(fill='x',padx=24,pady=3)
  views=ttk.Frame(self);views.pack(fill='both',expand=True,padx=22,pady=8);self.canvases=[]
  for title in ['ÖNCE','SONRA']:
   frame=ttk.Frame(views);frame.pack(side='left',fill='both',expand=True,padx=3);ttk.Label(frame,text=title).pack(anchor='w');c=tk.Canvas(frame,bg='#0c121c',highlightthickness=0);c.pack(fill='both',expand=True);self.canvases.append(c);c.bind('<Configure>',lambda e:self.draw());c.bind('<ButtonPress-1>',self.press);c.bind('<B1-Motion>',self.rotate);c.bind('<MouseWheel>',self.wheel)
  opts=ttk.Frame(self);opts.pack(fill='x',padx=22);ttk.Label(opts,text='Geometri:').pack(side='left');self.geom=tk.StringVar(value='1');self.geom_box=ttk.Combobox(opts,textvariable=self.geom,values=['1'],width=5,state='readonly');self.geom_box.pack(side='left');self.geom_box.bind('<<ComboboxSelected>>',lambda e:self.draw())
  ttk.Label(opts,text='  Sürükle: döndür • Tekerlek: yakınlaştır • Önizleme: örneklenmiş, dokusuz geometri (ilk 8 parça)').pack(side='left')
  self.log=tk.Text(self,height=6,bg='#0c121c',fg='#adc0d8',font=('Consolas',10),relief='flat');self.log.pack(fill='x',padx=22,pady=10)
  self.status=tk.StringVar(value='Hazır • FPS kazancı garanti edilmez. Çıktıyı MTA’da test edin.')
  ttk.Label(self,textvariable=self.status).pack(fill='x',padx=22,pady=(0,12));self.after(80,self.poll)
 def press(self,e):self.drag=e.x
 def rotate(self,e):
  if self.drag is not None:self.angle+=(e.x-self.drag)*.012;self.drag=e.x;self.draw()
 def wheel(self,e):self.zoom=max(.2,min(5,self.zoom*(1.1 if e.delta>0 else .9)));self.draw()
 def draw(self):
  for c,result in zip(self.canvases,[self.before,self.after_result]):
   c.delete('all');w,h=c.winfo_width(),c.winfo_height()
   if not result or not result.get('preview'):c.create_text(w/2,h/2,text='Model önizlemesi',fill='#51657e');continue
   idx=min(int(self.geom.get())-1,len(result['preview'])-1);tris=result['preview'][idx]['triangles']
   ref=self.before['preview'][min(idx,len(self.before['preview'])-1)]['triangles'];pts=[p for t in ref for p in t]
   if not pts:continue
   center=[(min(p[i] for p in pts)+max(p[i] for p in pts))/2 for i in range(3)];span=max(max(p[i] for p in pts)-min(p[i] for p in pts) for i in range(3));scale=min(w,h)*.65/max(span,.001)*self.zoom;co,si=math.cos(self.angle),math.sin(self.angle)
   projected=[]
   for t in tris:
    polygon=[];depth=0
    for p in t:
     x,y,z=[p[i]-center[i] for i in range(3)];rx=x*co-y*si;ry=x*si+y*co;polygon.extend((w/2+rx*scale,h/2+(.48*ry-.88*z)*scale));depth+=ry*.88+z*.48
    projected.append((depth,polygon))
   for _,poly in sorted(projected,reverse=True):c.create_polygon(poly,fill='#456386',outline='#89a6c8',width=.4)
 def add(self):
  if self.busy:return
  for name in filedialog.askopenfilenames(filetypes=[('MTA modelleri','*.dff *.col *.txd')]):
   p=Path(name)
   if p not in self.files:self.files.append(p);self.table.insert('', 'end',iid=str(len(self.files)-1),text=p.name,values=(p.suffix.upper(),f'{p.stat().st_size/1024:.1f} KB','Bekliyor'))
 def clear(self):
  if self.busy:return
  self.table.delete(*self.table.get_children());self.files=[];self.before=self.after_result=None;self.draw()
 def selected(self):return [(i,self.files[int(i)]) for i in self.table.selection()]
 def engine(self,req):
  node=str(BASE/'node.exe') if (BASE/'node.exe').exists() else shutil.which('node')
  if not node:raise RuntimeError('Node.js bulunamadı. Node.js 20+ kurun.')
  proc=subprocess.run([node,str(BASE/'engine.cjs')],input=json.dumps(req),encoding='utf-8',stdout=subprocess.PIPE,stderr=subprocess.PIPE,creationflags=getattr(subprocess,'CREATE_NO_WINDOW',0),timeout=180)
  if proc.returncode:raise RuntimeError(proc.stderr.strip() or 'Model işlenemedi')
  return json.loads(proc.stdout)
 def start(self,task):
  if self.busy:return
  self.busy=True;self.status.set('İşleniyor… Orijinal dosyalar korunuyor.');threading.Thread(target=task,daemon=True).start()
 def analyze(self):
  chosen=self.selected()
  if self.busy or not chosen:return
  i,p=chosen[0]
  def task():
   try:self.q.put(('analysis',i,self.engine({'input':str(p)})))
   except Exception as e:self.q.put(('error',i,str(e)))
   finally:self.q.put(('done',))
  self.start(task)
 def optimize(self):
  chosen=[(i,p) for i,p in self.selected() if p.suffix.lower()=='.dff']
  if self.busy:return
  if not chosen:messagebox.showinfo('DFF seçin','COL/TXD bu sürümde analiz edilir; optimizasyon için statik DFF seçin.');return
  folder=filedialog.askdirectory(title='Çıktı klasörü (ayrı oturum klasörü oluşturulacak)')
  if not folder:return
  profile=PROFILES[self.profile.get()];dest=Path(folder)/('optimized-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S-%f'));dest.mkdir()
  def task():
   for n,(i,p) in enumerate(chosen):
    try:
     before=self.engine({'input':str(p)});out=dest/(str(n+1)+'-'+p.stem+'-'+profile+'.dff');after=self.engine({'input':str(p),'profile':profile,'output':str(out)})
     report={k:v for k,v in after.items() if k!='preview'};(out.with_suffix('.json')).write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8');self.q.put(('result',i,before,after))
    except Exception as e:self.q.put(('error',i,str(e)))
   self.q.put(('done',str(dest)))
  self.start(task)
 def poll(self):
  try:
   while True:
    item=self.q.get_nowait();kind=item[0]
    if kind=='done':self.busy=False;self.status.set('Tamamlandı'+(' • '+item[1] if len(item)>1 else ''))
    elif kind=='error':self.table.set(item[1],'state','Desteklenmiyor / hata');self.log.insert('end',str(item[2])+'\n');self.log.see('end')
    elif kind in ('analysis','result'):
     i=item[1];result=item[-1]
     if result.get('type')=='DFF':
      self.before=item[2];self.after_result=result if kind=='result' else None;self.geom.set('1');self.geom_box.configure(values=[str(x+1) for x in range(len(result['preview']))]);self.angle=.6;self.zoom=1
      self.stats.set(f"Üçgen: {result['before']:,} → {result['after']:,}   |   Azalma: %{result['reduction']:.1f}   |   Vertex: {result['vertices']:,}   |   Materyal: {result['materials']}")
      self.table.set(i,'state',f"{result['before']:,} → {result['after']:,} üçgen");self.log.insert('end',json.dumps({k:v for k,v in result.items() if k not in ('preview','warnings')},ensure_ascii=False)+'\n');self.draw()
     else:self.before=self.after_result=None;self.draw();self.stats.set(result['type']+' • analiz tamamlandı');self.log.insert('end',json.dumps(result,ensure_ascii=False,indent=2)+'\n');self.table.set(i,'state','Analiz tamamlandı')
     self.log.see('end')
  except queue.Empty:pass
  self.after(80,self.poll)
if __name__=='__main__':
 app=App()
 if '--smoke' in sys.argv:app.update();app.destroy();print('GUI smoke PASS')
 else:app.mainloop()
