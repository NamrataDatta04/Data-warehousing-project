#!/usr/bin/env python3
"""Generate the synthetic source extracts for the Kereru Hardware Co-operative warehouse.

Everything here is invented. The script is seeded, so every run produces the same
files. It imitates what a head office really receives from owner-operated stores:

  * three point-of-sale systems with different layouts, date formats and GST treatment
  * store-local customer and item codes that clash between stores
  * refunds recorded three different ways
  * double-exported rows in the spreadsheet stores
  * monthly stock counts, quarterly operating costs and finance control totals

Usage:  python scripts/generate_source_data.py [--out data/raw] [--scale 1.0]
"""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import numpy as np
import pandas as pd

SEED = 2026
START, END = "2024-07-01", "2026-06-30"
GST = 0.15

# code, suburb, city, region, island, pos system, opened, floor m2, size, trade discount, rent $/m2/quarter
STORES = [
    ("AKL01", "Albany", "Auckland", "Auckland", "North", "pos_a", "2011-03-14", 2400, 1.35, 0.10, 9.0),
    ("AKL02", "Henderson", "Auckland", "Auckland", "North", "pos_b", "2014-08-01", 1800, 1.05, 0.10, 8.0),
    ("AKL03", "Mt Wellington", "Auckland", "Auckland", "North", "pos_a", "2008-10-06", 2600, 1.45, 0.10, 27.0),
    ("AKL04", "Manukau", "Auckland", "Auckland", "North", "pos_c", "2016-02-22", 2000, 1.20, 0.24, 8.5),
    ("HAM01", "Te Rapa", "Hamilton", "Waikato", "North", "pos_a", "2012-05-28", 1700, 0.95, 0.10, 6.5),
    ("TGA01", "Mount Maunganui", "Tauranga", "Bay of Plenty", "North", "pos_b", "2015-11-09", 1600, 1.00, 0.22, 7.0),
    ("NPE01", "Onekawa", "Napier", "Hawke's Bay", "North", "pos_c", "2017-07-03", 1200, 0.65, 0.10, 5.5),
    ("PMR01", "Roslyn", "Palmerston North", "Manawatū-Whanganui", "North", "pos_b", "2013-09-16", 1300, 0.70, 0.10, 5.5),
    ("WLG01", "Petone", "Lower Hutt", "Wellington", "North", "pos_a", "2010-04-19", 1900, 1.10, 0.10, 9.5),
    ("NSN01", "Stoke", "Nelson", "Nelson", "South", "pos_c", "2018-03-05", 1100, 0.60, 0.10, 5.5),
    ("CHC01", "Hornby", "Christchurch", "Canterbury", "South", "pos_a", "2009-06-22", 2200, 1.25, 0.10, 7.5),
    ("DUD01", "South Dunedin", "Dunedin", "Otago", "South", "pos_b", "2019-01-21", 1250, 0.70, 0.10, 5.5),
]
STORE_COLS = ["store_code", "suburb", "city", "region", "island", "pos_system", "opened_on",
              "floor_area_m2", "size", "trade_discount", "rent_rate"]

SUPPLIERS = [
    ("S01", "Southern Pine Timber", "New Zealand", 5),
    ("S02", "Tasman Building Products", "New Zealand", 7),
    ("S03", "Aotea Paints", "New Zealand", 6),
    ("S04", "Pacific Fasteners", "New Zealand", 4),
    ("S05", "Harbour Plumbing Supplies", "New Zealand", 8),
    ("S06", "Volt Electrical Wholesale", "Australia", 14),
    ("S07", "Shenzhen ProTool Co", "China", 45),
    ("S08", "GreenThumb Garden Supplies", "New Zealand", 6),
    ("S09", "EuroHand Tools GmbH", "Germany", 38),
]

# category -> (supplier, margin on list price, retail weight, trade weight, [(name, brand, unit, cost)])
CATALOGUE = {
    "Timber": ("S01", 0.24, 0.6, 3.0, [
        ("Framing Timber 90x45 H1.2 4.8m", "Southern Pine", "length", 21.50),
        ("Framing Timber 140x45 H3.2 4.8m", "Southern Pine", "length", 36.00),
        ("Decking Pine 140x32 H3.2 4.8m", "Southern Pine", "length", 29.00),
        ("Fence Paling 150x19 H3.2 1.8m", "Southern Pine", "each", 3.40),
        ("Fence Post 100x100 H4 2.4m", "Southern Pine", "each", 24.00),
        ("Plywood Structural 12mm 2400x1200", "Southern Pine", "sheet", 58.00),
        ("Dressed Pine 90x18 2.4m", "Southern Pine", "length", 9.80),
        ("Landscaping Sleeper 200x50 H4 2.4m", "Southern Pine", "each", 31.00),
    ]),
    "Building Supplies": ("S02", 0.26, 0.5, 2.4, [
        ("Plasterboard Standard 10mm 2400x1200", "Tasman", "sheet", 19.50),
        ("Plasterboard Wet Area 10mm 2400x1200", "Tasman", "sheet", 31.00),
        ("Insulation Wall Batts R2.6 Pack", "Tasman", "pack", 74.00),
        ("Insulation Ceiling Batts R3.6 Pack", "Tasman", "pack", 92.00),
        ("Concrete Mix 20kg", "Tasman", "bag", 7.20),
        ("Rapid Set Cement 20kg", "Tasman", "bag", 9.10),
        ("Building Wrap 1.35m x 37m", "Tasman", "roll", 88.00),
        ("Fibre Cement Sheet 6mm 2400x1200", "Tasman", "sheet", 41.00),
    ]),
    "Paint": ("S03", 0.38, 1.6, 0.8, [
        ("Interior Low Sheen White 10L", "Aotea", "each", 86.00),
        ("Interior Low Sheen White 4L", "Aotea", "each", 44.00),
        ("Exterior Semi Gloss 10L", "Aotea", "each", 104.00),
        ("Primer Sealer Undercoat 4L", "Aotea", "each", 39.00),
        ("Decking Stain Natural 5L", "Aotea", "each", 71.00),
        ("Roller Kit 230mm", "Aotea", "each", 11.50),
        ("Paint Brush Set 3 Piece", "Aotea", "each", 9.20),
        ("Masking Tape 48mm x 50m", "Aotea", "each", 3.90),
    ]),
    "Fasteners": ("S04", 0.42, 0.9, 2.2, [
        ("Decking Screws Stainless 10g x 65mm Box 500", "Pacific", "box", 49.00),
        ("Framing Nails Galvanised 90mm 5kg", "Pacific", "box", 24.00),
        ("Wood Screws 8g x 40mm Box 1000", "Pacific", "box", 17.50),
        ("Coach Bolts M12 x 150mm Pack 10", "Pacific", "pack", 13.00),
        ("Joist Hangers 90x45 Pack 20", "Pacific", "pack", 26.00),
        ("Construction Adhesive 375ml", "Pacific", "each", 4.60),
        ("Wall Anchors Assorted Pack 100", "Pacific", "pack", 6.80),
    ]),
    "Plumbing": ("S05", 0.36, 1.0, 1.2, [
        ("PVC Pipe 100mm x 3m", "Harbour", "length", 19.00),
        ("PVC Pipe 40mm x 3m", "Harbour", "length", 7.40),
        ("Kitchen Mixer Tap Chrome", "Harbour", "each", 78.00),
        ("Toilet Suite Close Coupled", "Harbour", "each", 169.00),
        ("Hot Water Cylinder Valve Kit", "Harbour", "each", 54.00),
        ("Garden Hose 18mm x 30m", "Harbour", "each", 31.00),
        ("Silicone Sealant Bathroom 300ml", "Harbour", "each", 5.10),
    ]),
    "Electrical": ("S06", 0.37, 1.2, 0.9, [
        ("LED Downlight 9W Warm White", "Volt", "each", 8.40),
        ("Extension Lead Heavy Duty 15m", "Volt", "each", 22.00),
        ("Power Board 6 Outlet Surge", "Volt", "each", 16.50),
        ("Smoke Alarm 10 Year Photoelectric", "Volt", "each", 21.00),
        ("LED Floodlight 30W Sensor", "Volt", "each", 33.00),
        ("Heat Pump Outdoor Cover", "Volt", "each", 47.00),
    ]),
    "Power Tools": ("S07", 0.33, 1.0, 1.5, [
        ("Cordless Drill Driver 18V Kit", "ProTool", "each", 118.00),
        ("Impact Driver 18V Skin", "ProTool", "each", 96.00),
        ("Circular Saw 185mm 1800W", "ProTool", "each", 104.00),
        ("Angle Grinder 125mm 900W", "ProTool", "each", 62.00),
        ("Random Orbital Sander 125mm", "ProTool", "each", 71.00),
        ("Battery 18V 5.0Ah", "ProTool", "each", 84.00),
        ("Mitre Saw 254mm Sliding", "ProTool", "each", 289.00),
        ("Rotary Hammer Drill SDS 800W", "ProTool", "each", 142.00),
    ]),
    "Hand Tools": ("S09", 0.40, 1.1, 1.1, [
        ("Claw Hammer 20oz Fibreglass", "EuroHand", "each", 19.00),
        ("Spirit Level 1200mm", "EuroHand", "each", 28.00),
        ("Tape Measure 8m", "EuroHand", "each", 9.40),
        ("Chisel Set 4 Piece", "EuroHand", "each", 26.00),
        ("Hand Saw 550mm", "EuroHand", "each", 17.00),
        ("Utility Knife Retractable", "EuroHand", "each", 6.20),
        ("Socket Set 40 Piece", "EuroHand", "each", 52.00),
    ]),
    "Garden": ("S08", 0.41, 1.9, 0.3, [
        ("Potting Mix Premium 40L", "GreenThumb", "bag", 7.10),
        ("Compost 40L", "GreenThumb", "bag", 4.90),
        ("Lawn Seed Hardwearing 2kg", "GreenThumb", "each", 21.00),
        ("Weed Killer Concentrate 1L", "GreenThumb", "each", 18.50),
        ("Raised Garden Bed Kit 1.2m", "GreenThumb", "each", 63.00),
        ("Garden Spade Long Handle", "GreenThumb", "each", 24.00),
        ("Bark Mulch 50L", "GreenThumb", "bag", 6.30),
        ("Tomato Fertiliser 1.5kg", "GreenThumb", "each", 8.80),
    ]),
}

SEASON = {1: 1.05, 2: 1.00, 3: 1.00, 4: 0.95, 5: 0.90, 6: 0.85, 7: 0.85, 8: 0.90, 9: 1.00, 10: 1.10, 11: 1.15, 12: 1.20}
DOW = [0.95, 0.95, 1.00, 1.00, 1.05, 1.25, 1.00]  # Monday .. Sunday
CLOSED = ["2024-12-25", "2025-04-18", "2025-12-25", "2026-04-03"]  # Christmas Day, Good Friday
CAT_MONTH = {"Garden": {9: 1.5, 10: 1.9, 11: 1.9, 12: 1.7, 1: 1.5, 5: 0.6, 6: 0.5, 7: 0.5},
             "Paint": {10: 1.3, 11: 1.3, 12: 1.3, 1: 1.3, 2: 1.3, 3: 1.2},
             "Electrical": {5: 1.2, 6: 1.3, 7: 1.3}}
# (effective date, {category: (cost multiplier, price multiplier)})
PRICE_CHANGES = [
    ("2025-04-01", {"Timber": (1.09, 1.03), "Building Supplies": (1.09, 1.03), "Fasteners": (1.03, 1.03),
                    "Plumbing": (1.03, 1.03), "Electrical": (1.03, 1.03), "Garden": (1.03, 1.03)}),
    ("2026-01-01", {"Power Tools": (1.06, 1.06), "Hand Tools": (1.06, 1.06), "Paint": (1.04, 1.04)}),
]

FIRST = ["Aroha", "Ben", "Chloe", "Daniel", "Emma", "Finn", "Grace", "Hemi", "Isla", "Jack", "Kiri", "Liam",
         "Mia", "Nikau", "Olivia", "Priya", "Quinn", "Rawiri", "Sophie", "Tane", "Uma", "Vikram", "Wiremu",
         "Xavier", "Yuki", "Zoe", "Anika", "Manaia", "Sione", "Mele", "Arjun", "Mei", "Lucas", "Ruby"]
LAST = ["Smith", "Wilson", "Williams", "Brown", "Taylor", "Jones", "Singh", "Wang", "Anderson", "Li", "Walker",
        "Thompson", "Patel", "Harris", "Tamihana", "Ngata", "Parata", "Kaur", "Chen", "Campbell", "Stewart",
        "Robinson", "Tuilagi", "Fifita", "Young", "Mitchell", "Clark", "Scott", "Morgan", "Edwards"]


def build_products() -> pd.DataFrame:
    rows, n = [], 1000
    for cat, (sup, margin, w_retail, w_trade, items) in CATALOGUE.items():
        for name, brand, unit, cost in items:
            n += 1
            rows.append(dict(sku=f"KH{n}", product_name=name, category=cat, brand=brand, unit_of_measure=unit,
                             supplier_code=sup, base_cost=cost, base_price=round(cost / (1 - margin), 2),
                             w_retail=w_retail, w_trade=w_trade))
    return pd.DataFrame(rows)


def build_price_list(products: pd.DataFrame) -> pd.DataFrame:
    rows = []
    cost = products.base_cost.to_numpy().copy()
    price = products.base_price.to_numpy().copy()
    for sku, c, p in zip(products.sku, cost, price):
        rows.append((sku, "2024-01-01", round(p, 2), round(c, 2)))
    for eff, changes in PRICE_CHANGES:
        for i, (sku, cat) in enumerate(zip(products.sku, products.category)):
            if cat in changes:
                cm, pm = changes[cat]
                cost[i], price[i] = round(cost[i] * cm, 2), round(price[i] * pm, 2)
                rows.append((sku, eff, price[i], cost[i]))
    return pd.DataFrame(rows, columns=["sku", "effective_from", "list_price_excl_gst", "standard_cost"])


def price_arrays(products, price_list, dates):
    """Return price[sku_index, day_index] and cost[...] using the price list in force each day."""
    pl = price_list.assign(effective_from=pd.to_datetime(price_list.effective_from)).sort_values("effective_from")
    idx = {s: i for i, s in enumerate(products.sku)}
    price = np.zeros((len(products), len(dates)))
    cost = np.zeros_like(price)
    for r in pl.itertuples():
        mask = dates >= r.effective_from
        price[idx[r.sku], mask] = r.list_price_excl_gst
        cost[idx[r.sku], mask] = r.standard_cost
    return price, cost


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--out", default="data/raw")
    ap.add_argument("--scale", type=float, default=1.0, help="transaction volume multiplier")
    args = ap.parse_args()
    out = Path(args.out)
    if out.exists():
        shutil.rmtree(out)
    rng = np.random.default_rng(SEED)

    stores = pd.DataFrame(STORES, columns=STORE_COLS)
    products = build_products()
    price_list = build_price_list(products)
    dates = pd.date_range(START, END)
    n_s, n_d, n_p = len(stores), len(dates), len(products)
    price, cost = price_arrays(products, price_list, dates)

    # ---------------------------------------------------------------- transactions
    month = dates.month.to_numpy()
    lam = (16 * args.scale * stores["size"].to_numpy()[:, None]
           * np.array([SEASON[m] for m in month])[None, :]
           * np.array([DOW[d] for d in dates.dayofweek])[None, :]
           * (1 + 0.04 * np.arange(n_d) / 365)[None, :])
    lam[:, np.isin(dates.strftime("%Y-%m-%d"), CLOSED)] = 0
    n_txn = rng.poisson(lam)
    t_store = np.repeat(np.arange(n_s), n_txn.sum(axis=1))
    t_day = np.concatenate([np.repeat(np.arange(n_d), n_txn[s]) for s in range(n_s)])
    T = len(t_store)
    weekend = dates.dayofweek.to_numpy()[t_day] >= 5
    t_trade = rng.random(T) < np.where(weekend, 0.12, 0.42)
    t_secs = rng.integers(7 * 3600, 18 * 3600, T)

    # customers: local pools per store plus a pool of trade customers who buy at several stores
    cust_rows, pools = [], {}
    uid = 0

    def new_customers(n, ctype, home):
        nonlocal uid
        ids = []
        for _ in range(n):
            uid += 1
            f, l = FIRST[rng.integers(len(FIRST))], LAST[rng.integers(len(LAST))]
            cust_rows.append((uid, f, l, f"{f}.{l}{uid}@example.com".lower(), ctype, home))
            ids.append(uid)
        return np.array(ids)

    roaming = new_customers(90, "TRADE", None)
    t_cust = np.zeros(T, dtype=np.int64)  # 0 = walk-in
    for s in range(n_s):
        size = stores["size"][s]
        pools[s] = (new_customers(int(70 * size), "TRADE", stores.store_code[s]),
                    new_customers(int(900 * size), "RETAIL", stores.store_code[s]))
        for is_trade in (True, False):
            sel = np.flatnonzero((t_store == s) & (t_trade == is_trade))
            pool = pools[s][0 if is_trade else 1]
            w = 1 / np.arange(1, len(pool) + 1) ** 0.8
            pick = rng.choice(pool, size=len(sel), p=w / w.sum())
            if is_trade:
                roam = rng.random(len(sel)) < 0.12
                wr = 1 / np.arange(1, len(roaming) + 1) ** 0.5
                pick[roam] = rng.choice(roaming, size=roam.sum(), p=wr / wr.sum())
            else:
                pick[rng.random(len(sel)) > 0.45] = 0
            t_cust[sel] = pick
    customers = pd.DataFrame(cust_rows, columns=["uid", "first_name", "last_name", "email", "customer_type", "home"])

    # ---------------------------------------------------------------- sale lines
    n_lines = np.minimum(1 + rng.poisson(np.where(t_trade, 1.6, 0.9)), 6)
    l_txn = np.repeat(np.arange(T), n_lines)
    L = len(l_txn)
    l_trade, l_month = t_trade[l_txn], month[t_day[l_txn]]
    l_prod = np.zeros(L, dtype=np.int64)
    per_cat = products.groupby("category").sku.transform("count").to_numpy()
    for is_trade in (True, False):
        base = (products.w_trade if is_trade else products.w_retail).to_numpy() / per_cat
        for m in range(1, 13):
            w = base * np.array([CAT_MONTH.get(c, {}).get(m, 1.0) for c in products.category])
            sel = np.flatnonzero((l_trade == is_trade) & (l_month == m))
            l_prod[sel] = rng.choice(n_p, size=len(sel), p=w / w.sum())
    lines = pd.DataFrame({"txn": l_txn, "prod": l_prod}).drop_duplicates(["txn", "prod"]).reset_index(drop=True)
    lines["store"], lines["day"] = t_store[lines.txn], t_day[lines.txn]
    lines["trade"], lines["cust"] = t_trade[lines.txn], t_cust[lines.txn]
    L = len(lines)
    lines["price"] = price[lines["prod"], lines["day"]]
    cheap = lines.price.to_numpy() < 30
    lines["qty"] = 1 + rng.poisson(np.where(lines.trade, np.where(cheap, 3.0, 1.0), np.where(cheap, 1.0, 0.25)))
    trade_disc = stores.trade_discount.to_numpy()[lines.store] + rng.normal(0, 0.03, L)
    retail_disc = rng.choice([0.0, 0.05, 0.10], size=L, p=[0.85, 0.10, 0.05])
    lines["disc"] = np.round(np.clip(np.where(lines.trade, trade_disc, retail_disc), 0, 0.4) * 200) / 200
    lines["is_return"] = rng.random(L) < 0.022

    # ---------------------------------------------------------------- stockouts
    ym = dates.to_period("M")
    months = ym.unique()
    m_of_day = np.array([months.get_loc(p) for p in ym])
    south = (stores.island == "South").to_numpy()
    sup = products.supplier_code.to_numpy()
    so_lam = np.full((n_s, len(months), n_p), 0.3)
    so_lam[:, :, sup == "S07"] = 5.0
    so_lam[:, :, sup == "S09"] = 2.5
    so_lam[np.ix_(south, np.arange(len(months)), sup == "S07")] = 11.0
    so_lam[np.ix_(south, np.arange(len(months)), sup == "S09")] = 4.5
    late = np.isin(months.astype(str), ["2026-01", "2026-02", "2026-03"])  # port delays on imported tools
    so_lam[np.ix_(np.arange(n_s), late, sup == "S07")] *= 1.5
    days_in_month = np.array([p.days_in_month for p in months])
    stockout = np.minimum(rng.poisson(so_lam), days_in_month[None, :, None] - 2)
    l_month_idx = m_of_day[lines.day]
    p_lost = stockout[lines.store, l_month_idx, lines["prod"]] / days_in_month[l_month_idx]
    lines = lines[rng.random(L) >= p_lost].reset_index(drop=True)

    # ---------------------------------------------------------------- derived columns
    lines["date"] = dates[lines.day]
    lines["ts"] = lines.date + pd.to_timedelta(t_secs[lines.txn], unit="s")
    lines["sign"] = np.where(lines.is_return, -1, 1)
    lines["net"] = np.round(lines.qty * lines.price * (1 - lines.disc), 2)  # GST-exclusive, unsigned
    lines["quarter"] = lines.date.dt.year.astype(str) + "Q" + lines.date.dt.quarter.astype(str)
    lines["store_code"] = stores.store_code.to_numpy()[lines.store]
    lines["sku"] = products.sku.to_numpy()[lines["prod"]]
    lines = lines.sort_values(["store", "ts", "txn", "prod"]).reset_index(drop=True)
    lines["txn_seq"] = lines.groupby("store").txn.transform(lambda s: pd.factorize(s)[0] + 1)
    lines["line_no"] = lines.groupby("txn").cumcount() + 1
    # store-local customer numbers: the same number means different people in different stores
    lines["local_cust"] = 0
    known = lines.cust > 0
    lines.loc[known, "local_cust"] = lines[known].groupby("store").cust.transform(lambda s: pd.factorize(s)[0] + 1)
    cust = customers.set_index("uid")

    # ---------------------------------------------------------------- reference data
    ref = out / "reference"
    ref.mkdir(parents=True)
    st = stores.assign(store_name="Kererū Hardware " + stores.suburb)
    st[["store_code", "store_name", "suburb", "city", "region", "island", "pos_system", "opened_on",
        "floor_area_m2"]].to_csv(ref / "stores.csv", index=False)
    products[["sku", "product_name", "category", "brand", "unit_of_measure", "supplier_code"]].to_csv(
        ref / "product_catalogue.csv", index=False)
    price_list.to_csv(ref / "price_list.csv", index=False)
    pd.DataFrame(SUPPLIERS, columns=["supplier_code", "supplier_name", "country", "lead_time_days"]).to_csv(
        ref / "suppliers.csv", index=False)

    def local_customers(store_lines):
        d = store_lines[store_lines.cust > 0].drop_duplicates("local_cust")[["local_cust", "cust"]]
        return d.join(cust, on="cust").sort_values("local_cust")

    # ---------------------------------------------------------------- POS A: ISO dates, GST-exclusive
    item_map = []
    for s, code, pos in zip(range(n_s), stores.store_code, stores.pos_system):
        sl = lines[lines.store == s]
        folder = out / pos / code
        folder.mkdir(parents=True)
        lc = local_customers(sl)
        if pos == "pos_a":
            pd.DataFrame({
                "cust_id": "C" + lc.local_cust.astype(str).str.zfill(5), "first_name": lc.first_name,
                "last_name": lc.last_name, "email": lc.email, "customer_type": lc.customer_type,
            }).to_csv(folder / "customers.csv", index=False)
            a = pd.DataFrame({
                "txn_id": "T" + sl.txn_seq.astype(str).str.zfill(7), "line_no": sl.line_no,
                "sold_at": sl.ts.dt.strftime("%Y-%m-%d %H:%M:%S"), "sku": sl.sku, "qty": sl.qty,
                "unit_price_excl_gst": sl.price.map("{:.2f}".format),
                "discount_pct": (sl.disc * 100).map("{:.1f}".format),
                "cust_id": np.where(sl.cust > 0, "C" + sl.local_cust.astype(str).str.zfill(5), ""),
                "is_return": np.where(sl.is_return, "Y", "N"), "quarter": sl.quarter})
            for q, g in a.groupby("quarter"):
                g.drop(columns="quarter").to_csv(folder / f"sales_{q}.csv", index=False)

        # ------------------------------------------------------------ POS B: dd/mm/yyyy, GST-inclusive, local item codes
        elif pos == "pos_b":
            offset = 4000 + 37 * s
            codes = {sku: f"I-{offset + i}" for i, sku in enumerate(products.sku)}
            item_map += [(code, c, sku) for sku, c in codes.items()]
            pd.DataFrame({
                "Cust Ref": 100000 + lc.local_cust, "Full Name": lc.first_name + " " + lc.last_name,
                "Email": lc.email.str.upper().where(lc.local_cust % 7 == 0, lc.email),
                "Account Type": np.where(lc.customer_type == "TRADE", "TRADE ACCOUNT", "LOYALTY"),
            }).to_csv(folder / "customers.csv", index=False)
            price_inc = np.round(sl.price * (1 + GST), 2)
            b = pd.DataFrame({
                "Receipt No": sl.txn_seq, "Date": sl.ts.dt.strftime("%d/%m/%Y"), "Time": sl.ts.dt.strftime("%H:%M"),
                "Item Code": sl.sku.map(codes), "Qty": sl.qty, "Price Inc GST": price_inc.map("{:.2f}".format),
                "Disc $": np.round(sl.qty * price_inc * sl.disc, 2).map("{:.2f}".format),
                "Cust Ref": np.where(sl.cust > 0, (100000 + sl.local_cust).astype(str), ""),
                "Type": np.where(sl.is_return, "REFUND", "SALE"), "quarter": sl.quarter})
            for q, g in b.groupby("quarter"):
                g.drop(columns="quarter").to_csv(folder / f"sales_{q}.csv", index=False)

        # ------------------------------------------------------------ POS C: spreadsheet export, free-text products
        else:
            names = products.product_name.to_numpy()[sl["prod"]]
            style = rng.integers(0, 6, len(sl))
            messy = np.select([style == 0, style == 1, style == 2],
                              [np.char.upper(names.astype(str)), np.char.add("  ", names.astype(str)),
                               np.char.add(np.char.replace(names.astype(str), " ", "  ", count=1), " ")], names)
            emails = sl.cust.map(cust.email).fillna("")
            emails = emails.str.title().where(style == 3, emails)
            c = pd.DataFrame({
                "invoice_ref": code + "-" + sl.txn_seq.astype(str), "sale_date": sl.ts.dt.strftime("%d-%b-%y").str.lstrip("0"),
                "product": messy, "quantity": sl.qty * sl.sign,
                "line_total_incl_gst": (np.round(sl.net * (1 + GST), 2) * sl.sign).map("{:.2f}".format),
                "customer_email": emails,
                "account_type": np.where(sl.cust == 0, "", np.where(sl.trade, "Trade", "Cash")),
                "quarter": sl.quarter, "_date": sl.date})
            dup_quarter = {"AKL04": ("2025Q2", "2025-05-12", "2025-05-18"),
                           "NSN01": ("2025Q4", "2025-11-03", "2025-11-09")}.get(code)
            for q, g in c.groupby("quarter"):
                if dup_quarter and q == dup_quarter[0]:  # one week exported twice
                    again = g[(g._date >= dup_quarter[1]) & (g._date <= dup_quarter[2])]
                    g = pd.concat([g, again])
                g.drop(columns=["quarter", "_date"]).to_csv(folder / f"sales_{q}.csv", index=False)
    pd.DataFrame(item_map, columns=["store_code", "item_code", "sku"]).to_csv(ref / "pos_b_item_map.csv", index=False)

    # ---------------------------------------------------------------- inventory (monthly stock counts)
    inv = out / "inventory"
    inv.mkdir()
    sold = (lines.assign(m=m_of_day[lines.day], u=lines.qty * lines.sign)
            .groupby(["store", "m", "prod"]).u.sum())
    sold_arr = np.zeros((n_s, len(months), n_p))
    sold_arr[tuple(np.array(sold.index.to_list()).T)] = sold.to_numpy()
    target = np.maximum(sold_arr.mean(axis=1) * 1.4, 4)
    prev = np.round(target)
    for mi, per in enumerate(months):
        close = np.round(target * rng.uniform(0.5, 1.2, target.shape))
        close[stockout[:, mi, :] >= 10] = 0
        received = np.maximum(close - prev + sold_arr[:, mi, :], 0)
        ss, pp = np.meshgrid(np.arange(n_s), np.arange(n_p), indexing="ij")
        pd.DataFrame({"store_code": stores.store_code.to_numpy()[ss.ravel()], "sku": products.sku.to_numpy()[pp.ravel()],
                      "on_hand_qty": close.ravel().astype(int), "received_qty": received.ravel().astype(int),
                      "stockout_days": stockout[:, mi, :].ravel()}).to_csv(inv / f"stock_{per}.csv", index=False)
        prev = close

    # ---------------------------------------------------------------- finance: operating costs and control totals
    fin = out / "finance"
    fin.mkdir()
    signed_net = lines.net * lines.sign
    ctl = (lines.assign(net_sales_excl_gst=signed_net).groupby(["store_code", "quarter"], as_index=False)
           .net_sales_excl_gst.sum().round(2))
    ctl.to_csv(fin / "control_totals.csv", index=False)
    opex = ctl.merge(stores[["store_code", "floor_area_m2", "rent_rate"]], on="store_code")
    r = opex.net_sales_excl_gst
    noise = lambda: rng.uniform(0.95, 1.05, len(opex))  # noqa: E731
    pd.DataFrame({
        "store_code": opex.store_code, "quarter": opex.quarter,
        "rent": (opex.floor_area_m2 * opex.rent_rate).round(2),
        "wages": (12000 + 0.115 * r * noise()).round(2), "utilities": (2500 + 0.004 * r * noise()).round(2),
        "marketing": (0.012 * r * noise()).round(2), "other": (0.015 * r * noise()).round(2),
    }).to_csv(fin / "opex_quarterly.csv", index=False)

    n_files = sum(1 for _ in out.rglob("*.csv"))
    print(f"Wrote {n_files} files to {out}: {len(lines):,} sale lines, "
          f"{lines.groupby(['store', 'txn']).ngroups:,} transactions, {len(customers):,} customers, "
          f"${signed_net.sum():,.0f} net sales excl. GST")


if __name__ == "__main__":
    main()
