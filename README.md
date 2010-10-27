packø - Un package manager pacco.
=================================

Quello che voglio da questo package manager e' unire l'utile al dilettevole.

Deve essere flessibile come portage, ma deve essere semplice scrivere meta-pacchetti che vengono poi trasformati in pacchetti per essere poi installati.

Esempio:

    # FLAVOR="binary headers" packo install ncurses

Questo non fara' altro che dire a packo "sto cercando il pacchetto binario di ncurses, con gli headers grazie" ed andra' a scaricare ncurses-5.7-headers.pko.

Che stara' su qualche mirror e che sara' stato generato con:

    # FLAVOR="headers" packo build ncurses

Quando si fa un install senza la FLAVOR binary il pacchetto viene prima buildato e poi installato.

In caso non trovasse il pacchetto binario chiedera' all'utente se vuole provare a compilarlo o se vuole sborarsi.

Sfruttando la magia negra delle useflags di Gentoo si potra' ottenere un sistema solo binario senza troppi problemi.

I pacchetti saranno disponibili in .rbuild e .xml, i .rbuild non saranno altro che versioni molto migliorate delle ebuild scritte in Ruby, mentre i .xml non saranno altro che delle rappresentazioni dei pacchetti in XML, usando quindi i costrutti standard.

Il totale dei pacchetti installati ed i pacchetti installati volontariamente (world) saranno salvati in un file XML mentre ad ogni sync, a scelta, un database sqlite verra' rigenerato con i nuovi pacchetti per poi fare ricerche rapide.

La gestione di profili ed overlay sara' integrata in packo.

Di base packo sara' predisposto per supportare sistemi operativi multipli ed userlands multiple.

Si puntera' a targetare Linux ed OpenBSD in primis, altri a seguire.

Si tentera', comunque, di ottenere di default un sistema senza GNU, quindi Clang & friends.

La distribuzione che sfruttera' packo si chiamera' Amanda e sara' una meta-distribuzione che non sa che cazzo dice.

packo si occupera' anche di automatizzare l'installazione di pacchetti con i sistemi di vari linguaggi: CPAN, RubyGems, PEAR, PECL. :: Inventarsi un sistema modulare supergay per fare degli overlay veri e propri che si interfaccino direttamente con i sistemi di packaging dei linguaggi.

ncurses.rbuild

      Packo::Package.new('ncurses') {|p|
        p.use Packo::Autotools

        # ci sono gia' integrate dei flavor default che fanno robe default ed i vari cosi
        # aggiuntivi come Packo::Autotools possono modificarli e robba varia.
        #
        # Flavor standard: headers, doc, minimal, debug, binary
        p.flavors(
          :headers => Flavor.new('headers'),
          :doc     => Flavor.new('doc'),
          :minimal => Flavor.new('minimal'),
          :debug   => Flavor.new('debug'),

          :cxx => Flavor.new('cxx') {|f|
            f.enabled

            f.description = 'Enable C++ support' # se si omette la description viene usata quella di default, se presente
          },

          :unicode => Flavor.new('unicode') {|f|
            f.enabled

            # Flavor#on permette di eseguire qualcosa quando viene richiamata una certa funzione, in questo caso "configure"
            # che viene incluso da Packo::Autotools

            f.on('configure') {
              @configure.set('unicode', f.enabled?)
            }
          },

          :gpm => Flavor.new('gpm') {|f|
            f.description = 'Add mouse support.'

            f.on('initialize') {
              f.dependencies << 'gpm'
            }

            f.on('configure') {
              @configure.set('gpm', f.enabled?)
            }
          },

          :ada => Flavor.new('ada') {|f|
            f.description = 'Add ADA support.'

            f.on('configure') {
              @configure.set('ada', f.enabled?) 
            }
          }
        )

        p.source = 'http://ftp.gnu.org/pub/gnu/ncurses/ncurses-#{VERSION}.tar.gz'
      }

ncurses-5.7.rbuild

    Packo::Package.new('ncurses', '5.7')

Quando si installa un pacchetto viene caricato il nome.rbuild e nome-versione.rbuild, in modo da ottenere un oggetto funzionante con le robe al suo posto, in modo che se si va a modificare solo quattro cagate non ci si ritrovi con 8 file tutti uguali ed enormi.

In XML ncurses-5.7.rbuild sarebbe diventato:

    <package>
        <name>ncurses</name>
        <version>5.7</version>
    </package>

Ta dah, bello che fatto.

Variabile KERNEL (OpenBSD, Linux, ...), variabile COMPILER (GCC, Clang, ...).
