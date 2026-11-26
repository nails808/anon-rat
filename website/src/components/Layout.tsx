import { useState } from 'react'
import { Link, NavLink, Outlet } from 'react-router-dom'

export function Layout() {
  const [open, setOpen] = useState(false)
  const close = () => setOpen(false)

  return (
    <>
      <header className="nav">
        <div className="container nav-inner">
          <Link to="/" className="brand" onClick={close}>
            <span className="brand-mark">A</span>
            ANON
          </Link>
          <nav className={`nav-links ${open ? 'open' : ''}`}>
            <NavLink to="/" end onClick={close}>Overview</NavLink>
            <a href="/#features" onClick={close}>Modules</a>
            <NavLink to="/install" onClick={close}>Install</NavLink>
            <NavLink to="/privacy" onClick={close}>Privacy</NavLink>
            <a className="btn btn-sm" href="#download" onClick={close}>Get APK</a>
          </nav>
          <button className="nav-toggle" onClick={() => setOpen((v) => !v)} aria-label="Menu">☰</button>
        </div>
      </header>
      <Outlet />
      <footer className="footer">
        <div className="container footer-grid">
          <div>
            <div className="brand"><span className="brand-mark">A</span> ANON</div>
            <p className="muted" style={{ maxWidth: 360 }}>
              Closed-circle privacy console for Android. Official distribution node.
            </p>
          </div>
          <div>
            <h4>Product</h4>
            <Link to="/">Overview</Link>
            <Link to="/install">Install guide</Link>
            <a href="/#download">Download</a>
          </div>
          <div>
            <h4>Legal</h4>
            <Link to="/privacy">Privacy</Link>
            <Link to="/terms">Terms</Link>
            <a href="mailto:support@anon.example">Support</a>
          </div>
        </div>
        <div className="container copy">© 2026 ANON Labs · build channel stable · not affiliated with Google Play</div>
      </footer>
    </>
  )
}
