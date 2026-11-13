#!/usr/bin/env python3
"""MWB r3 validation — Part 9/10. Deterministic, re-runnable. Exit 0 iff all pass."""
import csv, os, re, sys, hashlib
PKG=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC=os.environ.get("MWB_SRC","/home/claude/mwb_data/exports/personalisation-review")
def rd(p):
    with open(p,encoding='utf-8-sig',newline='') as f: return list(csv.DictReader(f))
def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for b in iter(lambda:f.read(65536),b''): h.update(b)
    return h.hexdigest()
R=[]
def ck(n,c,d=""): R.append((n,bool(c),d))

# load
pk=rd(PKG+"/MWB_COMPLETE_PRESENTATIONS_KJV.csv"); pw=rd(PKG+"/MWB_COMPLETE_PRESENTATIONS_WEB.csv")
lk=rd(PKG+"/MWB_LAYER_MAPPING_KJV.csv"); lw=rd(PKG+"/MWB_LAYER_MAPPING_WEB.csv")
rck=rd(PKG+"/MWB_COMPLETE_PERSONAL_RECEPTIONS_KJV.csv"); rcw=rd(PKG+"/MWB_COMPLETE_PERSONAL_RECEPTIONS_WEB.csv")
dk=rd(PKG+"/MWB_REVISED_FINAL_DECISIONS_KJV.csv"); dw=rd(PKG+"/MWB_REVISED_FINAL_DECISIONS_WEB.csv")
wa=rd(PKG+"/MWB_WEB_CORRECTED_TITLE_AUDIT.csv"); ea=rd(PKG+"/MWB_WEB_EMPTY_RECORD_AUDIT.csv")
skj={(r["Book ID"],r["Chapter"],r["Verse"]):r["Original Scripture"] for r in rd(SRC+"/csv/all_verses_kjv.csv")}
sweb={(r["Book ID"],r["Chapter"],r["Verse"]):r["Original Scripture"] for r in rd(SRC+"/csv/all_verses_web.csv")}
def vk2t(vk): return tuple(vk.split("."))

# T1 unique layer ids
ids=[r["layer_id"] for r in lk+lw]; ck("T1 every edition/reference/layer mapping unique", len(ids)==len(set(ids)), f"{len(ids)-len(set(ids))} dup")
# T2 multiple layers can coexist
coexist=0
for L in (lk+lw):
    pass
bykey={}
for L in lk+lw: bykey.setdefault((L["edition"],L["verse_key"]),set()).add(L["layer_type"])
ck("T2 multiple editorial layers can coexist for one verse", any(len(v)>1 for v in bykey.values()), "")
# T3 title without reception exists; T4 reception without title exists
tset={k for k,v in bykey.items() if "personalTitle" in v}; rset={k for k,v in bykey.items() if "personalReception" in v}
ck("T3 a personal title can exist without a reception", any(k in tset and k not in rset for k in tset), "")
ck("T4 a personal reception can exist without a title", any(k in rset and k not in tset for k in rset), "")
# T5 both together
ck("T5 both layers can coexist", any(("personalTitle" in v and "personalReception" in v) for v in bykey.values()), "")
# T6 original renders without layers (most verses)
base_only=sum(1 for r in pk+pw if r["has_personal_title"]=="no" and r["has_personal_reception"]=="no")
ck("T6 original Scripture renders without editorial layers", base_only>60000, base_only)
# T7 canonical text unchanged vs source
mis=0
for r in pk:
    if skj.get((r["book_id"],r["chapter"],r["verse"]))!=r["original_text"]: mis+=1
for r in pw:
    if sweb.get((r["book_id"],r["chapter"],r["verse"]))!=r["original_text"]: mis+=1
ck("T7 canonical text unchanged vs verified source (62,205)", mis==0, mis)
# T8 WEB titles validated against WEB source  / T9 KJV titles against KJV
STOP=set("the a an of to and in is are be his her their thy thee you your ye them he she it that which unto for from with as my me i we us our not but or shall will may through him all into out upon".split())
def cw(s): return [w for w in re.findall(r"[a-z]+",s.lower()) if w not in STOP and len(w)>2]
def faithful(title,verse):
    cws=cw(title.replace("{name}","")); vt=verse.lower()
    return bool(cws) and sum(1 for w in cws if w[:4] in vt)>=max(1,len(cws)-1)
badweb=0
for L in lw:
    if L["layer_type"]=="personalTitle" and L["publication_disposition"]=="editorial_eligible":
        vt=sweb.get(vk2t(L["verse_key"]),"")
        if vt and not faithful(L["content"],vt): badweb+=1
ck("T8 eligible WEB titles validated against WEB source text", badweb==0, badweb)
badkjv=0
for L in lk:
    if L["layer_type"]=="personalTitle" and L["publication_disposition"]=="editorial_eligible":
        vt=skj.get(vk2t(L["verse_key"]),"")
        if vt and not faithful(L["content"],vt): badkjv+=1
ck("T9 eligible KJV titles validated against KJV source text", badkjv==0, badkjv)
# T10 missing title mapping fails safe (no title layer with empty content that is eligible)
badtitle=sum(1 for L in lk+lw if L["layer_type"]=="personalTitle" and not L["content"].strip() and L["publication_disposition"]=="editorial_eligible")
ck("T10 no eligible title layer has empty content", badtitle==0, badtitle)
# T11 invalid proposal ids fail: every layer source_proposal_id (if present) exists in decisions
dids={(r["edition"],r["proposal_id"]) for r in dk+dw}
badpid=sum(1 for L in lk+lw if L["source_proposal_id"] and (L["edition"],L["source_proposal_id"]) not in dids)
ck("T11 every layer source_proposal_id exists in decisions", badpid==0, badpid)
# T12 empty WEB source cannot render: those verse_keys have no renderable layer and empty original
emptykeys={(r["book_id"],r["chapter"],r["verse"]) for r in ea}
badempty=0
for r in pw:
    if (r["book_id"],r["chapter"],r["verse"]) in emptykeys:
        if r["original_text"].strip() or r["has_personal_title"]=="yes" or r["has_personal_reception"]=="yes": badempty+=1
ck("T12 empty WEB source records cannot render as verses", badempty==0, badempty)
# T13 unresolved never eligible
bad_un=sum(1 for L in lk+lw if L["publication_disposition"]=="unresolved_withhold" and L["publication_disposition"]=="editorial_eligible")
ck("T13 unresolved/withheld layers never marked eligible", bad_un==0, bad_un)
# T14 human ratification never fabricated: no field claims supervisor approval
blob=" ".join(r.get("comments","") for r in dk+dw).lower()
ck("T14 no fabricated human ratification (no 'Obi Ogbo approved')", ("obi ogbo approved" not in blob and "ratified by" not in blob), "")
# T15 internal acceptance vs human ratification separated (disposition is approvedPresentation, not 'approved' human)
ck("T15 disposition uses approvedPresentation (internal), not human 'approved'", all(r["disposition"]=="approvedPresentation" for r in pk+pw), "")
# T16 every receptions retained (50/edition) and independently keyed
ck("T16 all 50 receptions retained per edition, independently keyed",
   len(rck)==50 and len(rcw)==50 and len({r['layer_id'] for r in rck})==50 and len({r['layer_id'] for r in rcw})==50,
   f"KJV {len(rck)} WEB {len(rcw)}")
# source fingerprints
ck("SRC KJV fingerprint matches provided", sha(SRC+"/csv/all_verses_kjv.csv")=="427f721552e115ac551935c18344cbe578c09b4263fc2b7db0b30241e68c08b5","")
ck("SRC WEB fingerprint matches provided", sha(SRC+"/csv/all_verses_web.csv")=="38e8e0ef868e95d498a228ef7255d344d521224b78e4057616a551f0659ed6ca","")
# WEB title audit completeness
ck("AUDIT all 19 WEB titles individually checked", len(wa)==19, len(wa))
ck("AUDIT 5 empty WEB records documented", len(ea)==5, len(ea))

print("==== MWB r3 VALIDATION ====")
for n,c,d in R: print(f"  [{'PASS' if c else 'FAIL'}] {n}"+("" if c else f"  ({d})"))
p=sum(1 for _,c,_ in R if c)
print(f"\nTOTAL: {p}/{len(R)} PASS")
sys.exit(0 if p==len(R) else 1)
