/**
 * MazWaveTours secure publisher — Cloudflare Worker
 * Required secrets: GITHUB_TOKEN, ADMIN_PASSWORD
 */
const OWNER = "sesgoestudio";
const REPO = "MazWaveTours";
const BRANCH = "main";
const FILE_PATH = "index.html";
const ALLOWED_ORIGIN = "https://sesgoestudio.github.io";

function cors(origin) {
  const allowed = origin === ALLOWED_ORIGIN ? origin : ALLOWED_ORIGIN;
  return {
    "Access-Control-Allow-Origin": allowed,
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Vary": "Origin"
  };
}
function json(data, status, origin) {
  return new Response(JSON.stringify(data), {status, headers: {...cors(origin), "Content-Type":"application/json", "Cache-Control":"no-store"}});
}
function findObjectEnd(source, start) {
  let depth=0, quote=null, escaped=false;
  for(let i=start;i<source.length;i++){
    const ch=source[i];
    if(quote){ if(escaped) escaped=false; else if(ch==="\\") escaped=true; else if(ch===quote) quote=null; continue; }
    if(ch==='"' || ch==="'" || ch backtick) { quote=ch; continue; }
    if(ch==="{") depth++;
    if(ch==="}" && --depth===0) return i+1;
  }
  throw new Error("No se pudo identificar el bloque de datos del sitio");
}
async function github(path, init={}) {
  const response=await fetch("https://api.github.com"+path, {
    ...init,
    headers: {Authorization:"Bearer "+GITHUB_TOKEN, Accept:"application/vnd.github+json", "X-GitHub-Api-Version":"2022-11-28", ...(init.headers||{})}
  });
  const body=await response.json();
  if(!response.ok) throw new Error(body.message || "Error de GitHub");
  return body;
}
export default {
  async fetch(request, env) {
    const origin=request.headers.get("Origin") || "";
    if(request.method==="OPTIONS") return new Response(null,{status:204,headers:cors(origin)});
    if(!["POST"].includes(request.method)) return json({error:"Método no permitido"},405,origin);
    if(origin!==ALLOWED_ORIGIN) return json({error:"Origen no autorizado"},403,origin);
    let body;
    try { body=await request.json(); } catch { return json({error:"Solicitud inválida"},400,origin); }
    if(!env.ADMIN_PASSWORD || !env.GITHUB_TOKEN) return json({error:"Faltan secretos del servidor"},503,origin);
    if(typeof body.password!=="string" || body.password!==env.ADMIN_PASSWORD) return json({error:"Contraseña incorrecta"},401,origin);
    if(new URL(request.url).pathname==="/auth") return json({ok:true},200,origin);
    if(new URL(request.url).pathname!=="/publish") return json({error:"Ruta no encontrada"},404,origin);
    const data=body.data;
    if(!data || typeof data!=="object" || !Array.isArray(data.items) || data.items.length>200) return json({error:"Datos del catálogo inválidos"},400,origin);
    try {
      const current=await github(`/repos/${OWNER}/${REPO}/contents/${FILE_PATH}?ref=${BRANCH}`);
      const decoded=Uint8Array.from(atob(current.content.replace(/\\n/g,"")),c=>c.charCodeAt(0));
      const source=new TextDecoder().decode(decoded);
      const marker="const defaultData =";
      const markerAt=source.indexOf(marker);
      if(markerAt<0) throw new Error("No se encontró el catálogo en index.html");
      const objectStart=source.indexOf("{",markerAt+marker.length);
      if(objectStart<0) throw new Error("Bloque de catálogo inválido");
      const objectEnd=findObjectEnd(source,objectStart);
      const updated=source.slice(0,objectStart)+JSON.stringify(data,null,4)+source.slice(objectEnd);
      const bytes=new TextEncoder().encode(updated);
      let binary=""; for(const byte of bytes) binary+=String.fromCharCode(byte);
      await github(`/repos/${OWNER}/${REPO}/contents/${FILE_PATH}`,{
        method:"PUT",
        headers:{"Content-Type":"application/json"},
        body:JSON.stringify({message:"Actualizar catálogo desde el administrador",content:btoa(binary),sha:current.sha,branch:BRANCH})
      });
      return json({ok:true},200,origin);
    } catch(error) { return json({error:error.message || "Error al publicar"},500,origin); }
  }
};
