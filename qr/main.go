package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"image"
	"image/color"
	"image/draw"
	"image/png"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"strings"

	"github.com/golang/freetype"
	"github.com/golang/freetype/truetype"
)

func main() {
	// cards, err := getCards()
	// if err != nil {
	// 	log.Fatalf("failed reading cards: %s", err)
	// }
	data := readTranslations()
	// fmt.Println(data)
	// fmt.Println(toCamelCase(strings.ToLower("NUM_1"), true))
	// return
	fontBytes, err := ioutil.ReadFile("impact.ttf")
	if err != nil {
		log.Panicln(err)
	}
	f, err := truetype.Parse(fontBytes)
	if err != nil {
		log.Panicln(err)
	}

	items, err := os.Open("../lib/items.dart")
	defer items.Close()

	scanner := bufio.NewScanner(items)
	start := false
	// re := regexp.MustCompile(`'[A-Z_0-9]+'`)
	// const Item('MAGIC_BALL', 'magic_ball.png')
	re := regexp.MustCompile(`const Item\('([A-Z_0-9]+)', '([a-z_\d-\.]+)'`)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if start && line == "}" {
			start = false
		}

		if start {
			if matches := re.FindStringSubmatch(line); matches != nil {
				tag := matches[1]
				file := matches[2]
				text := tag
				text = strings.Title(strings.ToLower(strings.ReplaceAll(text, "_", " ")))
				id := "item" + toCamelCase(strings.ToLower(text), true)
				translatedText := data[id]
				gen(f, tag, file, translatedText, "card-tpl.png", "cards")
				gen(f, tag, file, translatedText, "card-tpl-bg.png", "cards-bg")
				// break
			}
		}

		if line == "class Items {" {
			start = true
		}
	}

	if err := scanner.Err(); err != nil {
		log.Fatal(err)
	}

	makeSprite("./cards", "sprite_nobg")
	makeSprite("./cards-bg", "sprite_bg")
	makePdf("sprites", "sprite_nobg")
	makePdf("sprites", "sprite_bg")
}

func gen(f *truetype.Font, tag, imageFile, text, bgTemplate, destDir string) {
	qrFile := fmt.Sprintf("qr_out/qr-%s", imageFile)
	outputFile := fmt.Sprintf("%s/card-%s", destDir, imageFile)
	imageFile = fmt.Sprintf("../assets/images/%s", imageFile)
	fmt.Println(tag, imageFile, text, qrFile, outputFile)

	// 750 x 1050
	card, err := os.Open(bgTemplate)
	if err != nil {
		log.Fatalf("failed to open: %s", err)
	}

	imgCard, err := png.Decode(card)
	if err != nil {
		log.Fatalf("failed to decode: %s", err)
	}
	defer card.Close()

	cmd := exec.Command("qrencode", "-m", "2", "-s", "12", "-o", qrFile, tag)
	if err = cmd.Run(); err != nil {
		log.Fatalf("failed to generate qr: %s", err)
	}

	qr, err := os.Open(qrFile)
	if err != nil {
		log.Fatalf("failed to open: %s", err)
	}
	imgQR, err := png.Decode(qr)
	if err != nil {
		log.Fatalf("failed to decode: %s", err)
	}
	defer qr.Close()

	icon, err := os.Open(imageFile)
	if err != nil {
		log.Fatalf("failed to open: %s", err)
	}
	imgIcon, err := png.Decode(icon)
	if err != nil {
		log.Fatalf("failed to decode: %s", err)
	}
	defer icon.Close()

	imgOutput := image.NewRGBA(imgCard.Bounds())
	draw.Draw(imgOutput, imgCard.Bounds(), imgCard, image.ZP, draw.Src)
	draw.Draw(imgOutput, imgQR.Bounds().Add(image.Pt(220, 730)), imgQR, image.ZP, draw.Over)
	// _ = resize.Resize(0, 400, imgIcon, resize.Lanczos3)
	// dst := image.NewRGBA(image.Rect(0, 0, src.Bounds().Max.X/2, src.Bounds().Max.Y/2))
	// draw.NearestNeighbor.Scale(dst, dst.Rect, imgIcon, imgIcon.Bounds(), draw.Over, nil)

	draw.Draw(imgOutput, imgIcon.Bounds().Add(image.Pt(100, 180)), imgIcon, image.ZP, draw.Over)

	textLength := len(text)
	red := color.RGBA{0, 68, 102, 255}
	size := 20.0
	letterWidth := 40
	y := 20
	if textLength > 10 {
		size = 15.0
		letterWidth = 30
		y = 35
	}

	fg, _ := image.NewUniform(red), image.White
	c := freetype.NewContext()
	c.SetDPI(300)
	c.SetFont(f)
	c.SetFontSize(size)
	c.SetClip(imgOutput.Bounds())
	c.SetDst(imgOutput)
	c.SetSrc(fg)

	x := (750 - textLength*letterWidth) / 2
	if x < 0 {
		x = 5
	}
	// fmt.Println(x)

	pt := freetype.Pt(x, y+int(c.PointToFixed(size)>>6))
	if _, err := c.DrawString(text, pt); err != nil {
		log.Fatalf("failed to draw text: %s", err)
	}

	output, err := os.Create(outputFile)
	if err != nil {
		log.Fatalf("failed to create: %s", err)
	}
	png.Encode(output, imgOutput)
	defer output.Close()
}

func readTranslations() map[string]string {
	f, err := os.Open("../lib/l10n/app_de.arb")
	defer f.Close()

	b, err := ioutil.ReadAll(f)
	if err != nil {

		log.Fatalf("failed to read translation file: %s", err)
	}
	var data map[string]string
	if err := json.Unmarshal(b, &data); err != nil {
		log.Fatalf("failed to decode translation file: %s", err)
	}

	ignore := []string{
		"itemsLeftYouHave",
		"item",
		"items",
		"itemsLeft",
	}
	items := map[string]string{}
	for k, v := range data {
		if strings.HasPrefix(k, "item") && !inSlice(k, ignore) {
			items[k] = v
		}
	}
	return items

}

func inSlice(a string, list []string) bool {
	for _, b := range list {
		if b == a {
			return true
		}
	}
	return false
}

var uppercaseAcronym = map[string]string{
	"ID": "id",
}

func toCamelCase(s string, initCase bool) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return s
	}
	if a, ok := uppercaseAcronym[s]; ok {
		s = a
	}

	n := strings.Builder{}
	n.Grow(len(s))
	capNext := initCase
	for i, v := range []byte(s) {
		vIsCap := v >= 'A' && v <= 'Z'
		vIsLow := v >= 'a' && v <= 'z'
		if capNext {
			if vIsLow {
				v += 'A'
				v -= 'a'
			}
		} else if i == 0 {
			if vIsCap {
				v += 'a'
				v -= 'A'
			}
		}
		if vIsCap || vIsLow {
			n.WriteByte(v)
			capNext = false
		} else if vIsNum := v >= '0' && v <= '9'; vIsNum {
			n.WriteByte(v)
			capNext = true
		} else {
			capNext = v == '_' || v == ' ' || v == '-' || v == '.'
		}
	}
	return n.String()
}

func getCards() ([]string, error) {
	var matches []string
	err := filepath.Walk("./cards", func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}
		if matched, err := filepath.Match("*.png", filepath.Base(path)); err != nil {
			return err
		} else if matched {
			matches = append(matches, path)
		}
		return nil
	})
	if err != nil {
		return nil, err
	}
	return matches, nil
}

func makeSprite(srcDir, name string) {
	files, err := ioutil.ReadDir(srcDir)
	if err != nil {
		log.Fatal(err)
	}

	var cards []string
	for _, f := range files {
		if strings.HasSuffix(f.Name(), ".png") {
			cards = append(cards, fmt.Sprintf("%s/%s", srcDir, f.Name()))
		}
	}

	var outFiles []string
	chunkSize := 5
	for i := 0; i < len(cards); i += chunkSize {
		end := i + chunkSize

		if end > len(cards) {
			end = len(cards)
		}

		outFile := fmt.Sprintf("sprites/%s_%d.png", name, len(outFiles))
		var subCards []string
		for _, v := range cards[i:end] {
			subCards = append(subCards, v)
		}

		fmt.Println(">", subCards)
		for j := len(subCards); j < chunkSize; j++ {
			subCards = append(subCards, "./card-tpl-blank.png")
		}

		subCards = append(subCards, "+append", outFile)
		fmt.Println("convert", subCards)
		cmd := exec.Command("convert", subCards...)
		if err := cmd.Run(); err != nil {
			log.Fatalf("failed to partial sprite qr: %s", err)
		}
		outFiles = append(outFiles, outFile)
	}

	outFiles = append(outFiles, "-append", fmt.Sprintf("sprites/%s.png", name))
	fmt.Println(outFiles)
	cmd := exec.Command("convert", outFiles...)
	if err := cmd.Run(); err != nil {
		log.Fatalf("failed to sprite: %s", err)
	}
}

func makePdf(srcDir, name string) {
	files, err := ioutil.ReadDir(srcDir)
	if err != nil {
		log.Fatal(err)
	}

	var sprites []string
	for _, f := range files {
		if strings.HasPrefix(f.Name(), name+"_") && strings.HasSuffix(f.Name(), ".png") {
			sprites = append(sprites, fmt.Sprintf("%s/%s", srcDir, f.Name()))
		}
	}

	// rotate
	rotatedName := fmt.Sprintf("rotated_%s", name)
	sprites = append(sprites, path.Join(srcDir, fmt.Sprintf("%s_%%d.png", rotatedName)))
	params := append([]string{"-rotate", "270"}, sprites...)
	cmd := exec.Command("convert", params...)
	if err := cmd.Run(); err != nil {
		log.Fatalf("failed to rotate sprites: %s", err)
	}

	files, err = ioutil.ReadDir(srcDir)
	if err != nil {
		log.Fatal(err)
	}

	var rotatedSprites []string
	for _, f := range files {
		if strings.HasPrefix(f.Name(), rotatedName+"_") && strings.HasSuffix(f.Name(), ".png") {
			rotatedSprites = append(rotatedSprites, fmt.Sprintf("%s/%s", srcDir, f.Name()))
		}
	}

	rotatedSprites = append(rotatedSprites, path.Join(srcDir, fmt.Sprintf("%s.pdf", name)))
	params = append([]string{"-page", "a4+100+0"}, rotatedSprites...)
	cmd = exec.Command("convert", params...)
	if err := cmd.Run(); err != nil {
		log.Fatalf("failed to pdf: %s", err)
	}
}
