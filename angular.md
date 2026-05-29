# 🅰️ Angular Interview Questions — Complete Guide

> **100+ questions** grouped by concept · With definitions, ✅ good examples, ❌ bad examples & 📚 reference links.
> Use `Ctrl+F` / `Cmd+F` to jump to any topic.

---

## 📋 Table of Contents
1. [Components & Templates](#1-components--templates)
2. [Directives](#2-directives)
3. [Dependency Injection & Services](#3-dependency-injection--services)
4. [Angular Modules & Standalone Components](#4-angular-modules--standalone-components)
5. [Routing & Navigation](#5-routing--navigation)
6. [Forms — Template-Driven & Reactive](#6-forms--template-driven--reactive)
7. [Change Detection & Performance](#7-change-detection--performance)
8. [Pipes](#8-pipes)
9. [HTTP & Interceptors](#9-http--interceptors)
10. [Angular Compilation, Build & Optimization](#10-angular-compilation-build--optimization)

---

# 1. Components & Templates

> 📚 Reference: https://angular.dev/guide/components
> 📚 Medium: https://medium.com/angular-in-depth/the-essential-difference-between-constructor-and-ngoninit-in-angular-c9930c209a42

---

## 1.1 Component Basics & the @Component Decorator

### Q1. What is an Angular Component? How do you create one, what are its parts, and what is the role of the @Component decorator?

**Answer:**
A component is the fundamental building block of Angular UI — it controls a patch of screen called a view. Every component consists of a TypeScript class holding logic and data, an HTML template defining the view, optional CSS styles scoped to the component, and a `@Component` decorator binding them together. The decorator tells Angular this class is a component and provides metadata like `selector`, `templateUrl`, and `changeDetection` strategy.

❌ **Wrong — missing decorator, Angular won't recognize this as a component:**
```typescript
class ProductCard {
  title = 'Widget';
}
```

✅ **Correct:**
```typescript
import { Component, Input, ChangeDetectionStrategy } from '@angular/core';

@Component({
  selector: 'app-product-card',
  templateUrl: './product-card.component.html',
  styleUrls: ['./product-card.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class ProductCardComponent {
  @Input() title: string = '';
  @Input() price: number = 0;
}
```

---

### Q2. What are Angular lifecycle hooks? Explain ngOnInit, ngOnDestroy, ngOnChanges, ngAfterViewInit, and ngAfterContentInit with their correct use cases.

**Answer:**
Lifecycle hooks are methods Angular calls at specific moments in a component's life. `ngOnInit` runs once after the first `ngOnChanges` and is ideal for initialization logic. `ngOnDestroy` runs before Angular destroys the component — use it to clean up subscriptions. `ngOnChanges` fires whenever an `@Input` property changes. `ngAfterViewInit` fires after the component's view and child views are initialized. `ngAfterContentInit` fires after content projected via `ng-content` is initialized.

❌ **Wrong — doing HTTP calls in constructor, not cleaning up subscriptions:**
```typescript
export class UserComponent {
  constructor(private userService: UserService) {
    // Bad: constructor should only inject dependencies
    this.userService.getUsers().subscribe(u => this.users = u);
  }
  // No ngOnDestroy — memory leak!
}
```

✅ **Correct:**
```typescript
import { Component, OnInit, OnDestroy, OnChanges, SimpleChanges, Input } from '@angular/core';
import { Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';

@Component({ selector: 'app-user', template: '' })
export class UserComponent implements OnInit, OnDestroy, OnChanges {
  @Input() userId!: string;
  private destroy$ = new Subject<void>();

  constructor(private userService: UserService) {}

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['userId'] && !changes['userId'].firstChange) {
      this.loadUser();
    }
  }

  ngOnInit(): void {
    this.loadUser();
  }

  private loadUser(): void {
    this.userService.getUser(this.userId)
      .pipe(takeUntil(this.destroy$))
      .subscribe(user => this.user = user);
  }

  ngOnDestroy(): void {
    this.destroy$.next();
    this.destroy$.complete();
  }
}
```

---

### Q3. How do @Input and @Output work? What are the rules for passing data between parent and child components?

**Answer:**
`@Input()` allows a parent component to pass data down to a child. `@Output()` with an `EventEmitter` allows a child to emit events up to the parent. This is the standard unidirectional data flow in Angular. Input properties can have aliases, default values, and transform functions (Angular 16+). Output events should use `EventEmitter` typed with the emitted value.

❌ **Wrong — mutating the input directly and not emitting output:**
```typescript
// Child
@Input() items: string[] = [];

addItem() {
  this.items.push('new'); // Bad: mutating parent's reference
}
```

✅ **Correct:**
```typescript
// child.component.ts
import { Component, Input, Output, EventEmitter } from '@angular/core';

@Component({
  selector: 'app-item-list',
  template: `
    <ul><li *ngFor="let item of items">{{ item }}</li></ul>
    <button (click)="onAdd()">Add</button>
  `
})
export class ItemListComponent {
  @Input() items: string[] = [];
  @Output() itemAdded = new EventEmitter<string>();

  onAdd(): void {
    this.itemAdded.emit('new item');
  }
}

// parent.component.html
// <app-item-list [items]="myItems" (itemAdded)="handleAdd($event)"></app-item-list>
```

---

### Q4. What are ViewChild and ContentChild? How do they differ, and when do you use each?

**Answer:**
`@ViewChild` queries an element or directive in the component's own template. `@ContentChild` queries an element or directive projected into the component via `<ng-content>`. `ViewChild` is available after `ngAfterViewInit`, and `ContentChild` after `ngAfterContentInit`. Accessing them before their respective lifecycle hooks returns `undefined`.

❌ **Wrong — accessing ViewChild in ngOnInit (too early):**
```typescript
@ViewChild('myInput') inputRef!: ElementRef;

ngOnInit() {
  this.inputRef.nativeElement.focus(); // undefined here!
}
```

✅ **Correct:**
```typescript
import { Component, ViewChild, ContentChild, ElementRef, AfterViewInit, AfterContentInit } from '@angular/core';

@Component({
  selector: 'app-panel',
  template: `<input #myInput type="text"><ng-content></ng-content>`
})
export class PanelComponent implements AfterViewInit, AfterContentInit {
  @ViewChild('myInput') inputRef!: ElementRef;
  @ContentChild('projectedBtn') btnRef!: ElementRef;

  ngAfterViewInit(): void {
    this.inputRef.nativeElement.focus(); // Safe here
  }

  ngAfterContentInit(): void {
    console.log('Projected button:', this.btnRef);
  }
}
```

---

### Q5. Explain ng-content and content projection. What are multi-slot projection and conditional projection?

**Answer:**
Content projection allows a parent to insert HTML into designated slots of a child component using `<ng-content>`. Multi-slot projection uses the `select` attribute to route different content to different slots based on CSS selectors. Conditional projection with `ngTemplateOutlet` lets you render projected content conditionally. This is Angular's equivalent of "slots" in Web Components.

❌ **Wrong — trying to project content without ng-content:**
```typescript
@Component({
  selector: 'app-card',
  template: `<div class="card"><!-- content never appears --></div>`
})
export class CardComponent {}
// <app-card><p>This text is lost</p></app-card>
```

✅ **Correct — multi-slot projection:**
```typescript
@Component({
  selector: 'app-card',
  template: `
    <div class="card">
      <div class="card-header">
        <ng-content select="[card-title]"></ng-content>
      </div>
      <div class="card-body">
        <ng-content select="[card-body]"></ng-content>
      </div>
      <div class="card-footer">
        <ng-content></ng-content>
      </div>
    </div>
  `
})
export class CardComponent {}

// Usage:
// <app-card>
//   <h2 card-title>My Title</h2>
//   <p card-body>Body content</p>
//   <button>Footer button</button>
// </app-card>
```

---

### Q6. What are @HostBinding and @HostListener? How do you apply them in a component vs a directive?

**Answer:**
`@HostBinding` binds a property of the host element to a component/directive property. `@HostListener` listens to events on the host element. They allow a component or directive to interact with its host DOM element without using `ElementRef` directly, keeping the code clean and testable. Both can also be expressed in the `host` metadata object of `@Component` or `@Directive`.

❌ **Wrong — manually manipulating DOM with ElementRef:**
```typescript
constructor(private el: ElementRef) {}
ngOnInit() {
  this.el.nativeElement.style.backgroundColor = 'yellow'; // Brittle, not SSR-safe
  this.el.nativeElement.addEventListener('click', () => { ... });
}
```

✅ **Correct:**
```typescript
import { Component, HostBinding, HostListener } from '@angular/core';

@Component({
  selector: 'app-highlight-box',
  template: `<ng-content></ng-content>`
})
export class HighlightBoxComponent {
  @HostBinding('style.background-color') bgColor = 'white';
  @HostBinding('class.active') isActive = false;

  @HostListener('mouseenter')
  onMouseEnter(): void {
    this.bgColor = 'yellow';
    this.isActive = true;
  }

  @HostListener('mouseleave')
  onMouseLeave(): void {
    this.bgColor = 'white';
    this.isActive = false;
  }
}
```

---

### Q7. How do you create and use dynamic components in Angular?

**Answer:**
Dynamic components are created at runtime rather than declared in a template. Use `ViewContainerRef.createComponent()` (Angular 13+) passing the component class directly. Before Angular 13, `ComponentFactoryResolver` was required. Dynamic components are useful for modals, toasts, and plugin-style architectures.

❌ **Wrong — old API still used in Angular 13+:**
```typescript
// Deprecated approach
const factory = this.resolver.resolveComponentFactory(AlertComponent);
this.container.createComponent(factory);
```

✅ **Correct (Angular 13+):**
```typescript
import { Component, ViewChild, ViewContainerRef } from '@angular/core';
import { AlertComponent } from './alert.component';

@Component({
  selector: 'app-root',
  template: `<ng-container #container></ng-container>`
})
export class AppComponent {
  @ViewChild('container', { read: ViewContainerRef }) container!: ViewContainerRef;

  showAlert(message: string): void {
    this.container.clear();
    const ref = this.container.createComponent(AlertComponent);
    ref.instance.message = message;
    ref.instance.closed.subscribe(() => ref.destroy());
  }
}
```

---

### Q8. What are the different component communication patterns in Angular?

**Answer:**
Angular supports several patterns: (1) `@Input/@Output` for parent-child communication, (2) a shared `Service` with `BehaviorSubject` for sibling or distant component communication, (3) `@ViewChild` for direct parent-to-child method calls, (4) `EventBus` pattern using a service, and (5) NgRx/signals store for application-wide state. Choosing the right pattern depends on the relationship between components and the complexity of the data flow.

❌ **Wrong — using global variables or direct DOM manipulation for cross-component communication:**
```typescript
// Anti-pattern: global state
(window as any).sharedData = { user: 'John' };
// Another component reads it — untestable, no change detection
```

✅ **Correct — shared service with BehaviorSubject:**
```typescript
// shared.service.ts
import { Injectable } from '@angular/core';
import { BehaviorSubject } from 'rxjs';

@Injectable({ providedIn: 'root' })
export class SharedService {
  private userSubject = new BehaviorSubject<string>('');
  user$ = this.userSubject.asObservable();

  setUser(name: string): void {
    this.userSubject.next(name);
  }
}

// Component A (sender)
this.sharedService.setUser('John');

// Component B (receiver)
this.sharedService.user$.pipe(takeUntil(this.destroy$)).subscribe(name => this.userName = name);
```

---

### Q9. What is the difference between a component's constructor and ngOnInit? When should you use each?

**Answer:**
The constructor is a TypeScript/JavaScript concept called before Angular sets up the component — it should only be used for dependency injection. `ngOnInit` is an Angular lifecycle hook called after Angular initializes all data-bound properties — it's the right place for initialization logic, HTTP calls, and setting up subscriptions. Using the constructor for business logic makes testing harder because Angular DI isn't fully set up yet.

❌ **Wrong:**
```typescript
export class DashboardComponent {
  data: any;
  constructor(private api: ApiService) {
    // Bad: @Input values not available yet
    this.api.getData().subscribe(d => this.data = d);
  }
}
```

✅ **Correct:**
```typescript
export class DashboardComponent implements OnInit {
  @Input() userId!: string;
  data: any;

  constructor(private api: ApiService) {}
  // Constructor only injects — no logic

  ngOnInit(): void {
    // @Input values are available here
    this.api.getData(this.userId).subscribe(d => this.data = d);
  }
}
```

---

### Q10. What is ng-template, ng-container, and how do they differ from regular HTML elements?

**Answer:**
`ng-template` defines a template fragment that is not rendered by default — it must be explicitly instantiated with `ngTemplateOutlet` or structural directives. `ng-container` is a grouping element that renders its children without adding any DOM element itself. Regular HTML elements always appear in the DOM. Use `ng-container` to apply structural directives without adding wrapper divs, and `ng-template` for reusable template fragments.

❌ **Wrong — using a div just to apply *ngIf causing layout issues:**
```html
<div *ngIf="isLoggedIn">
  <span>Welcome</span>
  <span>User</span>
</div>
<!-- The div breaks flexbox layout -->
```

✅ **Correct:**
```html
<!-- ng-container: no extra DOM element -->
<ng-container *ngIf="isLoggedIn">
  <span>Welcome</span>
  <span>User</span>
</ng-container>

<!-- ng-template: reusable fragment -->
<ng-template #loadingTpl>
  <app-spinner></app-spinner>
</ng-template>

<div *ngIf="data; else loadingTpl">
  {{ data | json }}
</div>

<!-- ngTemplateOutlet: explicit render -->
<ng-container *ngTemplateOutlet="loadingTpl"></ng-container>
```

---

# 2. Directives

> 📚 Reference: https://angular.dev/guide/directives
> 📚 Medium: https://medium.com/angular-in-depth/exploring-angular-dom-abstractions-80b3ebcfc02

---

## 2.1 Structural & Attribute Directives

### Q11. What are structural directives? Explain *ngIf, *ngFor, and *ngSwitch with their de-sugared forms.

**Answer:**
Structural directives change the DOM layout by adding or removing elements. They use the `*` prefix as syntactic sugar that Angular de-sugars into `<ng-template>` syntax. `*ngIf` conditionally renders an element. `*ngFor` repeats an element for each item in a collection. `*ngSwitch` renders one of several possible elements based on a matching value.

❌ **Wrong — using hidden instead of ngIf (element remains in DOM):**
```html
<app-heavy-component [hidden]="!isVisible"></app-heavy-component>
<!-- Component is created and running even when hidden -->
```

✅ **Correct — de-sugared forms shown:**
```html
<!-- *ngIf sugar -->
<div *ngIf="isLoggedIn; else guestTpl">Welcome back!</div>
<!-- De-sugared: -->
<ng-template [ngIf]="isLoggedIn" [ngIfElse]="guestTpl">
  <div>Welcome back!</div>
</ng-template>
<ng-template #guestTpl><div>Please log in</div></ng-template>

<!-- *ngFor with all exported values -->
<li *ngFor="let item of items; index as i; first as isFirst; last as isLast; trackBy: trackById">
  {{ i }}: {{ item.name }}
</li>

<!-- *ngSwitch -->
<ng-container [ngSwitch]="status">
  <span *ngSwitchCase="'active'">Active</span>
  <span *ngSwitchCase="'inactive'">Inactive</span>
  <span *ngSwitchDefault>Unknown</span>
</ng-container>
```

---

### Q12. How do you create a custom structural directive? Explain TemplateRef and ViewContainerRef.

**Answer:**
A custom structural directive uses `TemplateRef` (the template to instantiate) and `ViewContainerRef` (the container to render into). The directive receives the template via `TemplateRef` injection and controls rendering through `ViewContainerRef.createEmbeddedView()` and `ViewContainerRef.clear()`. The `*` prefix in usage de-sugars into `[directiveName]` on an `ng-template`.

❌ **Wrong — using ElementRef to show/hide instead of structural manipulation:**
```typescript
@Directive({ selector: '[appUnless]' })
export class UnlessDirective {
  @Input() set appUnless(val: boolean) {
    this.el.nativeElement.style.display = val ? 'none' : '';
    // Wrong: element is still in DOM, not truly structural
  }
  constructor(private el: ElementRef) {}
}
```

✅ **Correct:**
```typescript
import { Directive, Input, TemplateRef, ViewContainerRef } from '@angular/core';

@Directive({ selector: '[appUnless]' })
export class UnlessDirective {
  private hasView = false;

  constructor(
    private templateRef: TemplateRef<any>,
    private viewContainer: ViewContainerRef
  ) {}

  @Input() set appUnless(condition: boolean) {
    if (!condition && !this.hasView) {
      this.viewContainer.createEmbeddedView(this.templateRef);
      this.hasView = true;
    } else if (condition && this.hasView) {
      this.viewContainer.clear();
      this.hasView = false;
    }
  }
}

// Usage: <div *appUnless="isLoggedIn">Please log in</div>
```

---

### Q13. How do you create a custom attribute directive? What is exportAs and how is it used?

**Answer:**
An attribute directive changes the appearance or behavior of an existing element without altering the DOM structure. It uses `@Directive` with a selector typically in bracket notation. `exportAs` gives the directive a name so template references (`#ref="directiveName"`) can access the directive instance directly in the template, enabling parent components to call directive methods.

❌ **Wrong — hardcoding styles in directive, not reusable:**
```typescript
@Directive({ selector: '[appHighlight]' })
export class HighlightDirective {
  constructor(private el: ElementRef) {
    this.el.nativeElement.style.backgroundColor = 'yellow'; // Hardcoded, no input
  }
}
```

✅ **Correct with exportAs:**
```typescript
import { Directive, ElementRef, Input, HostListener } from '@angular/core';

@Directive({
  selector: '[appHighlight]',
  exportAs: 'appHighlight'
})
export class HighlightDirective {
  @Input('appHighlight') color: string = 'yellow';
  isHighlighted = false;

  constructor(private el: ElementRef) {}

  @HostListener('mouseenter') onEnter() {
    this.el.nativeElement.style.backgroundColor = this.color;
    this.isHighlighted = true;
  }

  @HostListener('mouseleave') onLeave() {
    this.el.nativeElement.style.backgroundColor = '';
    this.isHighlighted = false;
  }

  toggle(): void {
    this.isHighlighted ? this.onLeave() : this.onEnter();
  }
}

// Template usage with exportAs:
// <p [appHighlight]="'lightblue'" #hl="appHighlight">Hover me</p>
// <button (click)="hl.toggle()">Toggle</button>
```

---

### Q14. What is the difference between @HostBinding and @HostListener in directives? Give a real-world example of each.

**Answer:**
`@HostBinding` binds a host element's property, attribute, or class to a directive property. `@HostListener` registers an event listener on the host element. Together they allow a directive to react to host events and update host properties without touching the DOM imperatively. A real-world example is a form field directive that adds error classes and listens to blur events.

❌ **Wrong — imperatively querying and manipulating host DOM:**
```typescript
@Directive({ selector: '[appError]' })
export class ErrorDirective implements OnInit {
  ngOnInit() {
    this.el.nativeElement.classList.add('has-error');
    this.el.nativeElement.addEventListener('blur', () => { ... });
  }
}
```

✅ **Correct:**
```typescript
import { Directive, HostBinding, HostListener, Input } from '@angular/core';

@Directive({ selector: '[appValidField]' })
export class ValidFieldDirective {
  @Input() appValidField = true;

  @HostBinding('class.field-valid') get isValid() { return this.appValidField; }
  @HostBinding('class.field-invalid') get isInvalid() { return !this.appValidField; }
  @HostBinding('attr.aria-invalid') get ariaInvalid() { return !this.appValidField; }

  @HostListener('focus')
  onFocus(): void {
    console.log('Field focused, valid:', this.appValidField);
  }

  @HostListener('blur')
  onBlur(): void {
    console.log('Field blurred');
  }
}

// Usage: <input [appValidField]="form.get('email')?.valid" />
```

---

### Q15. How do you pass context to an ng-template? Explain $implicit and named context variables.

**Answer:**
When using `ngTemplateOutlet`, you can pass a context object. The `$implicit` key maps to the default template variable (used with `let-varName`). Named keys map to named template variables (used with `let-varName="keyName"`). This is how Angular's built-in directives like `*ngFor` expose `index`, `first`, `last`, etc., to the template.

❌ **Wrong — not passing context, template has no access to data:**
```html
<ng-template #itemTpl>
  <span>{{ item.name }}</span> <!-- item is undefined -->
</ng-template>
<ng-container *ngTemplateOutlet="itemTpl"></ng-container>
```

✅ **Correct:**
```html
<!-- Define template with context variables -->
<ng-template #itemTpl let-item let-idx="index" let-isLast="last">
  <div [class.last]="isLast">
    {{ idx }}: {{ item.name }}
  </div>
</ng-template>

<!-- Provide context -->
<ng-container *ngFor="let product of products; index as i; last as isLast">
  <ng-container *ngTemplateOutlet="itemTpl; context: { $implicit: product, index: i, last: isLast }">
  </ng-container>
</ng-container>
```

---

### Q16. What is the difference between a component and a directive in Angular?

**Answer:**
A component is a directive with a template — it creates its own view in the DOM. A directive modifies the behavior or appearance of an existing element without creating a new view. Components use `@Component` (which extends `@Directive`) and require a `template` or `templateUrl`. Directives use `@Directive`. You can only have one component per element, but multiple directives.

❌ **Wrong — creating a component when a directive is more appropriate:**
```typescript
// Overkill: using a component just to add tooltip behavior
@Component({
  selector: '[appTooltip]',
  template: `<ng-content></ng-content><div class="tooltip">{{text}}</div>`
})
export class TooltipComponent { @Input() text = ''; }
```

✅ **Correct:**
```typescript
// Use a directive to add tooltip behavior to any existing element
@Directive({ selector: '[appTooltip]' })
export class TooltipDirective implements OnDestroy {
  @Input('appTooltip') text = '';
  private tooltipEl: HTMLElement | null = null;

  @HostListener('mouseenter') show() {
    this.tooltipEl = document.createElement('div');
    this.tooltipEl.textContent = this.text;
    this.tooltipEl.className = 'tooltip';
    document.body.appendChild(this.tooltipEl);
  }

  @HostListener('mouseleave') hide() {
    this.tooltipEl?.remove();
    this.tooltipEl = null;
  }

  ngOnDestroy() { this.tooltipEl?.remove(); }
}
// <button [appTooltip]="'Save document'">Save</button>
```

---

### Q17. How do you apply multiple structural directives to the same element?

**Answer:**
Angular does not allow two structural directives on the same element because each one wraps the element in an `ng-template`, and nesting them creates ambiguity. The solution is to use `ng-container` to apply one directive and the host element for the other, or chain them on separate `ng-container` elements.

❌ **Wrong — two structural directives on same element (compile error):**
```html
<!-- ERROR: Can't have multiple template bindings on one element -->
<tr *ngFor="let row of rows" *ngIf="row.visible">
  <td>{{ row.name }}</td>
</tr>
```

✅ **Correct:**
```html
<!-- Use ng-container for the outer directive -->
<ng-container *ngFor="let row of rows">
  <tr *ngIf="row.visible">
    <td>{{ row.name }}</td>
  </tr>
</ng-container>

<!-- Or with nested ng-containers -->
<ng-container *ngIf="isTableVisible">
  <ng-container *ngFor="let row of rows">
    <tr *ngIf="row.active">
      <td>{{ row.name }}</td>
    </tr>
  </ng-container>
</ng-container>
```

---

### Q18. What is the NgClass and NgStyle directive? When should you use them vs class and style bindings?

**Answer:**
`NgClass` applies CSS classes conditionally using an object, array, or string. `NgStyle` applies inline styles conditionally. Direct class bindings (`[class.active]="condition"`) and style bindings (`[style.color]="value"`) are simpler and preferred for single classes/styles. Use `NgClass` and `NgStyle` when applying multiple classes/styles based on complex conditions.

❌ **Wrong — using NgClass for a single class (over-engineered):**
```html
<div [ngClass]="{'active': isActive}">Content</div>
<!-- Simpler alternatives exist -->
```

✅ **Correct — using the right tool for the job:**
```html
<!-- Single class: use class binding -->
<div [class.active]="isActive">Single class</div>

<!-- Single style: use style binding -->
<div [style.color]="textColor">Styled text</div>

<!-- Multiple classes: NgClass shines -->
<div [ngClass]="{
  'active': isActive,
  'disabled': isDisabled,
  'highlight': isHighlighted,
  'error': hasError
}">Multi-class element</div>

<!-- Multiple styles: NgStyle -->
<div [ngStyle]="{
  'color': textColor,
  'font-size.px': fontSize,
  'background-color': bgColor
}">Multi-style element</div>
```

---

### Q19. How do you write unit tests for a custom directive?

**Answer:**
Test directives by creating a simple host component in the test file that uses the directive, then compile it with `TestBed`. Query the host element or the directive instance via `fixture.debugElement.query`. Trigger events with `triggerEventHandler` and assert on DOM state or directive properties.

❌ **Wrong — not creating a host component, testing directive in isolation:**
```typescript
// Directives need a host element — can't test without one
const directive = new HighlightDirective(); // Missing ElementRef injection
```

✅ **Correct:**
```typescript
import { Component } from '@angular/core';
import { TestBed, ComponentFixture } from '@angular/core/testing';
import { By } from '@angular/platform-browser';
import { HighlightDirective } from './highlight.directive';

@Component({
  template: `<p [appHighlight]="'red'">Test</p>`
})
class TestHostComponent {}

describe('HighlightDirective', () => {
  let fixture: ComponentFixture<TestHostComponent>;

  beforeEach(() => {
    TestBed.configureTestingModule({
      declarations: [HighlightDirective, TestHostComponent]
    });
    fixture = TestBed.createComponent(TestHostComponent);
    fixture.detectChanges();
  });

  it('should highlight on mouseenter', () => {
    const p = fixture.debugElement.query(By.css('p'));
    p.triggerEventHandler('mouseenter', null);
    fixture.detectChanges();
    expect(p.nativeElement.style.backgroundColor).toBe('red');
  });
});
```

---

### Q20. What are standalone directives (Angular 14+) and how do they differ from module-based directives?

**Answer:**
Standalone directives (Angular 14+) include `standalone: true` in their `@Directive` decorator and do not need to be declared in an `NgModule`. They can be imported directly into standalone components or other NgModules. They reduce boilerplate and improve tree-shaking because each directive manages its own dependencies.

❌ **Wrong — forgetting to declare/import the directive, causing template errors:**
```typescript
// Module-based: forgot to add to NgModule declarations
@Directive({ selector: '[appFocus]' })
export class FocusDirective {}
// ERROR: 'appFocus' is not a known attribute
```

✅ **Correct — standalone directive:**
```typescript
import { Directive, HostListener, ElementRef } from '@angular/core';

@Directive({
  selector: '[appAutoFocus]',
  standalone: true  // No NgModule needed
})
export class AutoFocusDirective {
  constructor(private el: ElementRef) {}

  ngAfterViewInit() {
    this.el.nativeElement.focus();
  }
}

// Use directly in a standalone component:
@Component({
  standalone: true,
  imports: [AutoFocusDirective], // Import directly, no module
  template: `<input appAutoFocus placeholder="Auto-focused" />`
})
export class LoginComponent {}
```

---

# 3. Dependency Injection & Services

> 📚 Reference: https://angular.dev/guide/di
> 📚 Medium: https://medium.com/angular-in-depth/angular-dependency-injection-and-tree-shakeable-tokens-4588a8f70d5d

---

## 3.1 DI Fundamentals & Providers

### Q21. What is Dependency Injection in Angular? How does the injector hierarchy work?

**Answer:**
Dependency Injection (DI) is a design pattern where a class receives its dependencies from an external source rather than creating them. Angular has a hierarchical injector system: the root injector (created at bootstrap), module-level injectors, and component-level injectors. When a token is requested, Angular walks up the injector tree until it finds a provider. This hierarchy allows services to be scoped — a component-level service creates a new instance per component.

❌ **Wrong — manually instantiating a service (bypasses DI, no singleton behavior):**
```typescript
export class OrderComponent {
  private orderService = new OrderService(); // Not injectable, creates new instance each time
}
```

✅ **Correct:**
```typescript
import { Injectable, Component } from '@angular/core';

@Injectable({ providedIn: 'root' }) // Root injector — singleton across the app
export class OrderService {
  getOrders() { return []; }
}

@Component({
  selector: 'app-order',
  template: '',
  providers: [LocalOrderService] // Component-level — new instance per component
})
export class OrderComponent {
  constructor(
    private orderService: OrderService,      // Singleton from root
    private localService: LocalOrderService  // New instance for this component
  ) {}
}
```

---

### Q22. What is the difference between providedIn: 'root', providedIn: 'platform', providing in a module, and providing in a component?

**Answer:**
`providedIn: 'root'` registers the service with the root injector — one instance for the entire app, tree-shakeable. `providedIn: 'platform'` creates a single instance shared across all Angular apps on the page (rare). Providing in a module (via `providers` array) scopes the service to that module's injector. Providing in a component creates a new instance per component instance and its children. Component-level providers are destroyed when the component is destroyed.

❌ **Wrong — providing a shared service at component level, causing multiple instances:**
```typescript
@Component({
  providers: [UserAuthService] // New instance every time — loses login state!
})
export class NavbarComponent {}
```

✅ **Correct:**
```typescript
// Root service (singleton, tree-shakeable)
@Injectable({ providedIn: 'root' })
export class AuthService { isLoggedIn = false; }

// Feature-scoped service (provided in lazy module)
@Injectable()
export class CartService {}

@NgModule({
  providers: [CartService] // Only available in this module's injector tree
})
export class ShopModule {}

// Component-scoped service (new instance per component)
@Injectable()
export class DialogService {}

@Component({
  providers: [DialogService] // Each instance gets its own DialogService
})
export class DialogComponent {}
```

---

### Q23. What are InjectionToken and when do you use them? How do you inject non-class values?

**Answer:**
`InjectionToken` provides a way to inject non-class values (strings, objects, functions, primitives) that can't be used as DI tokens since they have no unique class identity. They're also used for interface-based injection since TypeScript interfaces don't exist at runtime. `InjectionToken` is generic, type-safe, and supports tree-shaking via `providedIn` and `factory`.

❌ **Wrong — using a string token (no type safety, collisions possible):**
```typescript
providers: [{ provide: 'API_URL', useValue: 'https://api.example.com' }]
// inject('API_URL') — no type safety, string collision risk
```

✅ **Correct:**
```typescript
import { InjectionToken, inject } from '@angular/core';

// Define typed token
export const API_URL = new InjectionToken<string>('API_URL', {
  providedIn: 'root',
  factory: () => 'https://api.example.com' // tree-shakeable
});

export const APP_CONFIG = new InjectionToken<AppConfig>('APP_CONFIG');

// Provide in module
providers: [
  { provide: APP_CONFIG, useValue: { maxItems: 100, theme: 'dark' } }
]

// Inject in service (modern inject() function)
@Injectable({ providedIn: 'root' })
export class ApiService {
  private apiUrl = inject(API_URL);
  private config = inject(APP_CONFIG);
}

// Or via constructor
constructor(@Inject(API_URL) private apiUrl: string) {}
```

---

### Q24. Explain useClass, useFactory, useValue, and useExisting provider configurations.

**Answer:**
`useValue` provides a static value. `useClass` provides a class instance (different class can be provided for the same token — useful for mocking). `useFactory` provides a value returned by a factory function (can use `deps` for dependencies). `useExisting` creates an alias — both tokens resolve to the same instance (unlike `useClass` which creates a new instance).

❌ **Wrong — using useClass when useExisting is needed (creates two instances):**
```typescript
providers: [
  RealService,
  { provide: ServiceInterface, useClass: RealService } // TWO instances!
]
```

✅ **Correct:**
```typescript
// useValue: static config
{ provide: APP_TITLE, useValue: 'My App' }

// useClass: swap implementations
{ provide: LoggerService, useClass: environment.production ? ProdLogger : DevLogger }

// useFactory: dynamic computation with deps
{
  provide: HttpClient,
  useFactory: (backend: HttpBackend, interceptors: HttpInterceptor[]) => {
    return new HttpClient(backend);
  },
  deps: [HttpBackend, HTTP_INTERCEPTORS]
}

// useExisting: alias (same instance!)
providers: [
  RealService,
  { provide: ServiceAlias, useExisting: RealService } // Same instance
]
```

---

### Q25. What is the difference between providedIn: 'root' and providing in NgModule.providers?

**Answer:**
`providedIn: 'root'` registers the service directly on the service class — it is **tree-shakeable** (excluded from bundle if never injected) and creates one singleton for the entire app. NgModule `providers` array always bundles the service regardless of usage and creates an instance scoped to that module's injector. Prefer `providedIn: 'root'` for app-wide singletons.

❌ **Wrong — registering in NgModule providers (not tree-shakeable, risks multiple instances):**
```typescript
@NgModule({
  providers: [AnalyticsService] // always bundled even if unused
})
export class AppModule {}
```

✅ **Correct — tree-shakeable service:**
```typescript
@Injectable({ providedIn: 'root' })
export class AnalyticsService {
  track(event: string) { /* ... */ }
}
// If nothing ever injects AnalyticsService, it is excluded from the bundle
```

---

### Q26. What are multi-providers and when do you use them?

**Answer:**
Multi-providers allow multiple values to be registered for the same token using `multi: true`. All registered values are collected into an array. Angular's built-in `HTTP_INTERCEPTORS` token is a multi-provider — every interceptor you register is added to the array rather than replacing the previous one.

❌ **Wrong — registering an interceptor without multi: true (replaces all previous interceptors):**
```typescript
providers: [
  { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor }
  // Missing multi: true — replaces the entire interceptors list
]
```

✅ **Correct — multi: true accumulates all interceptors:**
```typescript
providers: [
  { provide: HTTP_INTERCEPTORS, useClass: AuthInterceptor,    multi: true },
  { provide: HTTP_INTERCEPTORS, useClass: LoggingInterceptor, multi: true },
  { provide: HTTP_INTERCEPTORS, useClass: CacheInterceptor,   multi: true }
]
// All three interceptors run in order for each request
```

---

# 4. Angular Modules & Standalone Components

> 📚 Reference: https://angular.dev/guide/ngmodules
> 📚 Standalone: https://angular.dev/guide/standalone-components

---

## 4.1 NgModule Architecture

### Q31. What is an NgModule and what are its four main metadata properties?

**Answer:**
An `NgModule` is a class decorated with `@NgModule` that organises a cohesive block of functionality. Its four main properties are: `declarations` (components, directives, pipes belonging to this module), `imports` (other modules whose exports are needed), `exports` (what this module makes available to importing modules), and `providers` (services registered in this module's injector). `bootstrap` is only used in the root module to specify the root component.

❌ **Wrong — declaring a component in multiple modules (compile error):**
```typescript
@NgModule({ declarations: [UserComponent] }) export class UsersModule {}
@NgModule({ declarations: [UserComponent] }) export class AdminModule {} // ERROR: duplicate declaration
```

✅ **Correct — declare once, export for reuse:**
```typescript
@NgModule({
  declarations: [UserCardComponent, UserAvatarComponent],
  imports:      [CommonModule],
  exports:      [UserCardComponent] // only export what others need
})
export class UsersModule {}

@NgModule({
  imports: [UsersModule] // gains access to UserCardComponent
})
export class AdminModule {}
```

---

### Q32. What is a standalone component (Angular 14+) and how does it differ from a module-based component?

**Answer:**
A standalone component uses `standalone: true` in `@Component` and manages its own imports directly — it does NOT need to be declared in an `NgModule`. It imports directives, pipes, and other components individually. Standalone is the recommended approach in Angular 17+ and enables better tree-shaking and simpler architecture.

❌ **Wrong — forgetting `standalone: true` and trying to import directly:**
```typescript
// Module-based component cannot be imported directly into another standalone component
@Component({ selector: 'app-card', template: '...' })
export class CardComponent {} // not standalone

@Component({
  standalone: true,
  imports: [CardComponent] // ERROR: CardComponent is not standalone
})
export class PageComponent {}
```

✅ **Correct — standalone component:**
```typescript
@Component({
  standalone: true,
  selector: 'app-card',
  imports: [NgClass, AsyncPipe],     // import what this template needs
  template: `<div [ngClass]="cls">{{ title }}</div>`
})
export class CardComponent {
  @Input() title = '';
  cls = 'card';
}

@Component({
  standalone: true,
  imports: [CardComponent, RouterLink], // use other standalone components directly
  template: `<app-card title="Hello" />`
})
export class PageComponent {}
```

---

### Q33. How do you bootstrap a standalone Angular application vs a module-based one?

**Answer:**
Module-based apps use `platformBrowserDynamic().bootstrapModule(AppModule)`. Standalone apps use `bootstrapApplication(AppComponent, { providers: [...] })` — no `AppModule` needed. Feature providers that were in `AppModule` (routing, HTTP, etc.) are passed directly to `bootstrapApplication` via provider functions like `provideRouter()`, `provideHttpClient()`.

❌ **Wrong — bootstrapping standalone component with deprecated module:**
```typescript
// main.ts — old pattern used for standalone component (still works but not recommended)
platformBrowserDynamic().bootstrapModule(AppModule); // AppModule just bootstraps AppComponent
```

✅ **Correct — fully standalone bootstrap:**
```typescript
// main.ts
import { bootstrapApplication }  from '@angular/platform-browser';
import { provideRouter }          from '@angular/router';
import { provideHttpClient }      from '@angular/common/http';
import { provideAnimations }      from '@angular/platform-browser/animations';
import { AppComponent }           from './app/app.component';
import { routes }                 from './app/app.routes';

bootstrapApplication(AppComponent, {
  providers: [
    provideRouter(routes),
    provideHttpClient(),
    provideAnimations(),
  ]
});
```

---

### Q34. What is the `forRoot()` / `forChild()` pattern and when is it used?

**Answer:**
`forRoot()` is a static method that returns a `ModuleWithProviders` object — it registers the module's services in the **root** injector exactly once. `forChild()` imports the module's declarations/directives without re-registering services, preventing duplicate singleton instances. `RouterModule` and `StoreModule` use this pattern. In standalone apps, use `provideRouter()` and `provideState()` instead.

❌ **Wrong — calling `forRoot` in a feature module (re-registers services, causes bugs):**
```typescript
@NgModule({
  imports: [RouterModule.forRoot(routes)] // should only be in AppModule
})
export class FeatureModule {}
```

✅ **Correct:**
```typescript
// AppModule — root: registers Router singleton
@NgModule({ imports: [RouterModule.forRoot(appRoutes)] })
export class AppModule {}

// FeatureModule — child: shares the same Router instance
@NgModule({ imports: [RouterModule.forChild(featureRoutes)] })
export class FeatureModule {}
```

---

### Q35. What is a lazy-loaded module and why does it improve initial load time?

**Answer:**
A lazy-loaded module is only downloaded and parsed when the user navigates to its route — not on initial app load. This reduces the initial bundle size, improving Time to Interactive. Angular uses dynamic `import()` to split the bundle at the router level. Standalone components lazy-load even more efficiently because they don't require a module wrapper.

❌ **Wrong — eagerly importing all feature modules in AppModule:**
```typescript
@NgModule({
  imports: [
    AdminModule,     // downloaded even if user never visits /admin
    ReportsModule,   // downloaded even for unauthenticated users
  ]
})
export class AppModule {}
```

✅ **Correct — lazy loading via router:**
```typescript
// app.routes.ts
export const routes: Routes = [
  {
    path: 'admin',
    loadChildren: () => import('./admin/admin.module').then(m => m.AdminModule),
    canMatch: [AuthGuard]
  },
  {
    path: 'reports',
    loadComponent: () => import('./reports/reports.component').then(c => c.ReportsComponent)
    // loadComponent for standalone — no module wrapper needed
  }
];
```

---

# 5. Routing & Navigation

> 📚 Reference: https://angular.dev/guide/routing
> 📚 Guards: https://angular.dev/guide/routing/router-guards

---

## 5.1 Router Setup & Navigation

### Q36. How do you set up routing in Angular and navigate programmatically?

**Answer:**
Define routes as an array of `Route` objects and register them with `provideRouter()` (standalone) or `RouterModule.forRoot()` (module-based). Use `RouterLink` directive for template navigation and `Router.navigate()` or `Router.navigateByUrl()` for programmatic navigation. `[routerLinkActive]` applies a CSS class to the active link.

❌ **Wrong — using `location.href` for navigation (bypasses Angular router, loses state):**
```typescript
navigateToOrders() {
  window.location.href = '/orders'; // full page reload — loses Angular state
}
```

✅ **Correct:**
```typescript
// Route definition
export const routes: Routes = [
  { path: '',        component: HomeComponent },
  { path: 'orders',  component: OrdersComponent },
  { path: 'orders/:id', component: OrderDetailComponent },
  { path: '**',      component: NotFoundComponent } // wildcard last
];

// Template navigation
// <a routerLink="/orders" routerLinkActive="active">Orders</a>
// <a [routerLink]="['/orders', order.id]">View</a>

// Programmatic navigation
constructor(private router: Router) {}

goToOrder(id: string) {
  this.router.navigate(['/orders', id], {
    queryParams: { tab: 'details' }
  });
}

goBack() {
  this.router.navigateByUrl('/orders');
}
```

---

### Q37. What are route guards and what is the difference between `canActivate`, `canDeactivate`, and `canMatch`?

**Answer:**
`canActivate` prevents navigation to a route if the user is not authorised. `canDeactivate` prevents leaving a route (e.g., unsaved form changes — prompts the user). `canMatch` determines whether a route even matches — unlike `canActivate`, if it returns false the router continues to the next route rather than blocking. In Angular 15+, all guards can be written as simple functions instead of classes.

❌ **Wrong — injecting AuthService inside a component to guard navigation (not a real guard):**
```typescript
ngOnInit() {
  if (!this.auth.isLoggedIn) {
    this.router.navigate(['/login']); // too late — component already constructed
  }
}
```

✅ **Correct — functional guard (Angular 15+):**
```typescript
// auth.guard.ts
import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService }   from './auth.service';

export const authGuard: CanActivateFn = (route, state) => {
  const auth   = inject(AuthService);
  const router = inject(Router);
  return auth.isLoggedIn()
    ? true
    : router.createUrlTree(['/login'], { queryParams: { returnUrl: state.url } });
};

// canDeactivate — prompt on unsaved changes
export const unsavedChangesGuard: CanDeactivateFn<EditFormComponent> = (component) =>
  component.isDirty() ? confirm('Discard unsaved changes?') : true;

// Route config
{ path: 'admin', component: AdminComponent, canActivate: [authGuard] },
{ path: 'edit',  component: EditFormComponent, canDeactivate: [unsavedChangesGuard] }
```

---

### Q38. What is a route resolver and when should you use one?

**Answer:**
A resolver pre-fetches data **before** a route activates. The component receives data already loaded via `ActivatedRoute.snapshot.data`. Use resolvers when you want to avoid a partially loaded view, but avoid them when the data load is slow — they block navigation entirely. For most cases, loading in `ngOnInit` with a skeleton UI is better UX.

❌ **Wrong — resolver blocking navigation for slow API (user sees frozen browser):**
```typescript
// If the API takes 3 seconds, the URL doesn't change and nothing happens
// for 3 seconds — bad UX
resolve: { order: SlowOrderResolver }
```

✅ **Correct — resolver for fast, critical data; skeleton loader for slow data:**
```typescript
// order.resolver.ts (functional, Angular 15+)
export const orderResolver: ResolveFn<Order> = (route) => {
  const id      = route.paramMap.get('id')!;
  const service = inject(OrderService);
  return service.getOrder(id); // fast call — acceptable to block
};

// Route config
{ path: 'orders/:id', component: OrderDetailComponent, resolve: { order: orderResolver } }

// Component — data available synchronously
export class OrderDetailComponent {
  order = inject(ActivatedRoute).snapshot.data['order'] as Order;
}
```

---

### Q39. How do you read route parameters and query parameters in a component?

**Answer:**
Use `ActivatedRoute` to access route state. `snapshot.paramMap` is a one-time read (fine for non-reused routes). `paramMap` as Observable handles the case where the same component is reused with different params (e.g., navigating from order/1 to order/2 without recreating the component). `queryParamMap` works the same way for query parameters.

❌ **Wrong — reading params from snapshot in a reusable route (misses updates):**
```typescript
ngOnInit() {
  const id = this.route.snapshot.paramMap.get('id'); // stale if route reused
  this.load(id);
}
```

✅ **Correct — Observable for reused routes:**
```typescript
export class OrderDetailComponent implements OnInit, OnDestroy {
  private destroy$ = new Subject<void>();

  constructor(private route: ActivatedRoute, private svc: OrderService) {}

  ngOnInit() {
    this.route.paramMap.pipe(
      map(p => p.get('id')!),
      switchMap(id => this.svc.getOrder(id)), // cancels in-flight request on param change
      takeUntil(this.destroy$)
    ).subscribe(order => this.order = order);

    // Query params
    this.route.queryParamMap.pipe(takeUntil(this.destroy$))
      .subscribe(q => this.tab = q.get('tab') ?? 'overview');
  }

  ngOnDestroy() { this.destroy$.next(); this.destroy$.complete(); }
}
```

---

### Q40. What are child routes and how do you configure nested routing?

**Answer:**
Child routes render inside a `<router-outlet>` in the parent component's template. They are defined in the `children` property of a route. The parent component must have its own `<router-outlet>` as a slot for child components. Use child routes for tab-based UIs, dashboards with sub-pages, or wizard steps.

❌ **Wrong — no nested outlet, child route components render in the wrong place:**
```typescript
@Component({ template: `<div>Order Details</div>` }) // No <router-outlet>
export class OrderComponent {}
// Child routes can't render anywhere
```

✅ **Correct:**
```typescript
// Routes
{ path: 'orders/:id', component: OrderComponent, children: [
    { path: '',        redirectTo: 'overview', pathMatch: 'full' },
    { path: 'overview', component: OrderOverviewComponent },
    { path: 'items',    component: OrderItemsComponent },
    { path: 'history',  component: OrderHistoryComponent },
]}

// OrderComponent template — provides the slot
@Component({
  template: `
    <nav>
      <a routerLink="overview" routerLinkActive="active">Overview</a>
      <a routerLink="items"    routerLinkActive="active">Items</a>
      <a routerLink="history"  routerLinkActive="active">History</a>
    </nav>
    <router-outlet></router-outlet>  <!-- child renders here -->
  `
})
export class OrderComponent {}
```

---

# 6. Forms — Template-Driven & Reactive

> 📚 Reference: https://angular.dev/guide/forms
> 📚 Reactive: https://angular.dev/guide/forms/reactive-forms

---

## 6.1 Template-Driven Forms

### Q41. What are template-driven forms and when do you use them?

**Answer:**
Template-driven forms are declared in the HTML template using `ngModel` and Angular directives. They are driven by the DOM — Angular creates the form model implicitly. Simpler for small forms with minimal validation. Requires `FormsModule`. Use for simple contact or login forms; prefer reactive forms for complex, dynamic, or heavily validated forms.

❌ **Wrong — forgetting FormsModule, ngModel not found:**
```typescript
// Component
@Component({ imports: [], template: `<input [(ngModel)]="name">` })
// ERROR: ngModel is not a known element property — FormsModule not imported
```

✅ **Correct:**
```typescript
@Component({
  standalone: true,
  imports: [FormsModule],
  template: `
    <form #loginForm="ngForm" (ngSubmit)="onSubmit(loginForm)">
      <input name="email"    [(ngModel)]="model.email"    required email #emailRef="ngModel">
      <span *ngIf="emailRef.invalid && emailRef.touched">Valid email required</span>

      <input name="password" [(ngModel)]="model.password" required minlength="8">

      <button [disabled]="loginForm.invalid">Login</button>
    </form>
  `
})
export class LoginComponent {
  model = { email: '', password: '' };
  onSubmit(form: NgForm) {
    if (form.valid) console.log(form.value);
  }
}
```

---

## 6.2 Reactive Forms

### Q42. What are reactive forms? Explain FormGroup, FormControl, and FormArray.

**Answer:**
Reactive forms create the form model explicitly in TypeScript. `FormControl` represents a single field. `FormGroup` groups related controls. `FormArray` handles dynamic lists of controls. The template binds to the model via `formGroup`, `formControlName`, and `formArrayName` directives. Requires `ReactiveFormsModule`. Preferred for complex forms, dynamic fields, and unit testability.

❌ **Wrong — mutating form value directly instead of using patchValue/setValue:**
```typescript
this.form.controls['email'].value = 'new@email.com'; // doesn't trigger validation
```

✅ **Correct:**
```typescript
@Component({
  standalone: true,
  imports: [ReactiveFormsModule],
  template: `
    <form [formGroup]="orderForm" (ngSubmit)="submit()">
      <input formControlName="customerName">
      <span *ngIf="customerName.errors?.['required'] && customerName.touched">Required</span>

      <div formArrayName="items">
        <div *ngFor="let item of items.controls; let i = index" [formGroupName]="i">
          <input formControlName="product">
          <input formControlName="qty" type="number">
        </div>
      </div>
      <button type="button" (click)="addItem()">Add Item</button>
      <button [disabled]="orderForm.invalid">Submit</button>
    </form>
  `
})
export class OrderFormComponent {
  orderForm = new FormGroup({
    customerName: new FormControl('', [Validators.required, Validators.minLength(3)]),
    items: new FormArray([this.createItem()])
  });

  get customerName() { return this.orderForm.get('customerName')!; }
  get items()        { return this.orderForm.get('items') as FormArray; }

  createItem() {
    return new FormGroup({
      product: new FormControl('', Validators.required),
      qty:     new FormControl(1,  [Validators.required, Validators.min(1)])
    });
  }

  addItem() { this.items.push(this.createItem()); }

  submit() {
    if (this.orderForm.valid) console.log(this.orderForm.value);
  }
}
```

---

### Q43. How do you create custom validators for reactive forms?

**Answer:**
A validator is a function that takes an `AbstractControl` and returns `ValidationErrors | null`. Synchronous validators return immediately. Async validators return `Observable<ValidationErrors | null>` or a `Promise`. Apply them as the second (sync) or third (async) argument to `FormControl`, or as the second argument to `FormGroup` for cross-field validation.

❌ **Wrong — validating in the component instead of a reusable validator:**
```typescript
submit() {
  if (this.form.value.password !== this.form.value.confirm) {
    this.error = 'Passwords must match'; // not reactive, not declarative
  }
}
```

✅ **Correct — reusable validators:**
```typescript
// sync validator
export function noSpacesValidator(control: AbstractControl): ValidationErrors | null {
  return control.value?.includes(' ')
    ? { noSpaces: 'Value must not contain spaces' }
    : null;
}

// cross-field group validator
export function passwordMatchValidator(group: AbstractControl): ValidationErrors | null {
  const pw  = group.get('password')?.value;
  const conf = group.get('confirm')?.value;
  return pw !== conf ? { passwordMismatch: true } : null;
}

// async validator — check username availability
export function usernameExistsValidator(svc: UserService): AsyncValidatorFn {
  return (control: AbstractControl): Observable<ValidationErrors | null> =>
    control.valueChanges.pipe(
      debounceTime(400),
      take(1),
      switchMap(val => svc.checkUsername(val)),
      map(taken => taken ? { usernameTaken: true } : null)
    );
}

// Usage:
this.form = new FormGroup({
  username: new FormControl('', [Validators.required, noSpacesValidator],
                                [usernameExistsValidator(this.userSvc)]),
  password: new FormControl('', Validators.required),
  confirm:  new FormControl('', Validators.required),
}, { validators: passwordMatchValidator });
```

---

### Q44. What is `ControlValueAccessor` and when do you implement it?

**Answer:**
`ControlValueAccessor` (CVA) is an interface that bridges a custom UI component with Angular forms — both template-driven and reactive. Implement it when building a custom form control (date picker, phone input, star rating) so it integrates seamlessly with `ngModel` and `formControlName`. You must implement `writeValue`, `registerOnChange`, `registerOnTouched`, and optionally `setDisabledState`, and provide `NG_VALUE_ACCESSOR`.

❌ **Wrong — custom component with @Input/@Output that can't be used with reactive forms:**
```typescript
// Works for simple data binding but doesn't integrate with form validation
@Component({ selector: 'app-rating' })
export class RatingComponent {
  @Input() value = 0;
  @Output() valueChange = new EventEmitter<number>();
}
// Can't use: <app-rating formControlName="rating"> — not a ControlValueAccessor
```

✅ **Correct — ControlValueAccessor:**
```typescript
@Component({
  selector: 'app-star-rating',
  template: `<span *ngFor="let s of stars; let i=index"
               (click)="setRating(i+1)">{{ i < _value ? '★' : '☆' }}</span>`,
  providers: [{ provide: NG_VALUE_ACCESSOR, useExisting: StarRatingComponent, multi: true }]
})
export class StarRatingComponent implements ControlValueAccessor {
  stars = [1, 2, 3, 4, 5];
  _value = 0;
  private onChange  = (_: number) => {};
  private onTouched = ()          => {};

  writeValue(value: number) { this._value = value ?? 0; }
  registerOnChange(fn: (v: number) => void)  { this.onChange  = fn; }
  registerOnTouched(fn: () => void)          { this.onTouched = fn; }
  setDisabledState(disabled: boolean)        { /* toggle disabled styling */ }

  setRating(rating: number) {
    this._value = rating;
    this.onChange(rating);
    this.onTouched();
  }
}

// Usage — works with both reactive and template-driven forms:
// <app-star-rating formControlName="rating"></app-star-rating>
// <app-star-rating [(ngModel)]="model.rating"></app-star-rating>
```

---

# 7. Change Detection & Performance

> 📚 Reference: https://angular.dev/guide/change-detection
> 📚 Signals: https://angular.dev/guide/signals

---

## 7.1 Change Detection Strategies

### Q45. What is Angular's default change detection and what is the `OnPush` strategy?

**Answer:**
Angular's **Default** strategy checks every component in the tree on every change detection cycle — triggered by any event, timer, or HTTP response. **OnPush** limits checks to when: an `@Input` reference changes, an event originates from the component or its descendants, the `async` pipe unwraps a new value, or `ChangeDetectorRef.markForCheck()` is called. OnPush dramatically reduces unnecessary checks in large trees.

❌ **Wrong — Default change detection in a large list component that receives frequent data:**
```typescript
@Component({
  // no changeDetection specified = ChangeDetectionStrategy.Default
  template: `<div *ngFor="let item of items">{{ item.price | currency }}</div>`
})
export class PriceListComponent {
  @Input() items: Product[] = [];
  // Every click anywhere in the app triggers checking ALL items — very expensive
}
```

✅ **Correct — OnPush with immutable data:**
```typescript
@Component({
  changeDetection: ChangeDetectionStrategy.OnPush,
  template: `<div *ngFor="let item of items; trackBy: trackById">
    {{ item.price | currency }}
  </div>`
})
export class PriceListComponent {
  @Input() items: Product[] = []; // only checked when reference changes

  // Trigger update by providing NEW array reference, not mutating:
  // this.items = [...this.items, newItem]; ✅
  // this.items.push(newItem);             ❌ (same reference, OnPush won't detect)

  trackById(_: number, item: Product) { return item.id; }
}
```

---

### Q46. When do you use `ChangeDetectorRef` methods: `markForCheck`, `detectChanges`, and `detach`?

**Answer:**
`markForCheck()` marks the component and ancestors for checking on the next CD cycle — use with OnPush when you push state changes outside Angular's zone (WebSocket, worker message). `detectChanges()` immediately runs CD on this component and its subtree — useful in unit tests or after manual DOM manipulation. `detach()` completely removes the component from CD — use for high-frequency data (charts) that manage their own rendering.

❌ **Wrong — calling detectChanges in a tight loop (performance bomb):**
```typescript
onMessage(data: any) {
  this.data = data;
  this.cdr.detectChanges(); // called 60 times/second — hammers CD
}
```

✅ **Correct — throttle updates and use markForCheck:**
```typescript
@Component({ changeDetection: ChangeDetectionStrategy.OnPush })
export class LiveChartComponent implements OnInit, OnDestroy {
  constructor(private cdr: ChangeDetectorRef, private ws: WebSocketService) {}

  ngOnInit() {
    this.ws.messages$.pipe(
      throttleTime(100), // max 10 updates/sec
      takeUntil(this.destroy$)
    ).subscribe(data => {
      this.chartData = data;
      this.cdr.markForCheck(); // schedule one CD pass ✅
    });
  }
}
```

---

## 7.2 Angular Signals (Angular 16/17+)

### Q47. What are Angular Signals and how do they differ from RxJS Observables?

**Answer:**
A `signal` is a reactive primitive that holds a value and notifies consumers when the value changes. Unlike Observables, signals are **synchronous**, always have a current value (no subscription needed to read), and integrate directly with Angular's change detection — `signal()` tells Angular exactly which template expressions to re-evaluate, enabling **fine-grained reactivity** without zone.js. Signals are simpler for local state; Observables excel for async streams, event pipelines, and complex operators.

❌ **Wrong — using a BehaviorSubject where a signal is simpler:**
```typescript
export class CounterComponent {
  private _count$ = new BehaviorSubject(0);
  count$ = this._count$.asObservable();

  increment() { this._count$.next(this._count$.value + 1); }
  // Template: {{ count$ | async }} — needs async pipe, subscription, etc.
}
```

✅ **Correct — signal for simple local state:**
```typescript
import { signal, computed, effect } from '@angular/core';

@Component({
  template: `
    <p>Count: {{ count() }}</p>
    <p>Double: {{ double() }}</p>
    <button (click)="increment()">+</button>
    <button (click)="reset()">Reset</button>
  `
})
export class CounterComponent {
  count  = signal(0);                       // writable signal
  double = computed(() => this.count() * 2); // derived signal — auto-updates

  constructor() {
    effect(() => {
      console.log(`Count changed to ${this.count()}`); // runs on every count change
    });
  }

  increment() { this.count.update(c => c + 1); } // update via function
  reset()     { this.count.set(0); }             // set to a specific value
}
```

---

### Q48. What are `computed()` and `effect()` in Angular Signals?

**Answer:**
`computed()` creates a **derived, read-only signal** that recalculates only when its dependencies change — it is memoised. `effect()` runs a **side-effect function** whenever any signal it reads changes — use for logging, localStorage sync, or external library updates. Never modify signals inside an `effect` (causes infinite loops). Effects are automatically cleaned up when the component is destroyed.

❌ **Wrong — recomputing derived values manually in every update:**
```typescript
items = signal<Product[]>([]);
total = 0; // plain variable, not reactive

add(p: Product) {
  this.items.update(i => [...i, p]);
  this.total = this.items().reduce((s, i) => s + i.price, 0); // manual sync
}
// If items changes from anywhere else, total is stale
```

✅ **Correct — computed is always consistent:**
```typescript
import { signal, computed, effect } from '@angular/core';

export class CartComponent {
  items  = signal<Product[]>([]);
  total  = computed(() => this.items().reduce((s, i) => s + i.price, 0));
  count  = computed(() => this.items().length);
  taxed  = computed(() => this.total() * 1.18);

  constructor() {
    effect(() => {
      // Syncs to localStorage whenever items changes — runs automatically
      localStorage.setItem('cart', JSON.stringify(this.items()));
    });
  }

  add(p: Product)    { this.items.update(list => [...list, p]); }
  remove(id: string) { this.items.update(list => list.filter(p => p.id !== id)); }
}
```

---

### Q49. What is `toSignal()` and `toObservable()` in Angular? How do you bridge Signals and RxJS?

**Answer:**
`toSignal(observable$)` converts an Observable to a signal — the signal always holds the latest emitted value. `toObservable(signal)` converts a signal back to an Observable. They bridge the reactive primitives. `toSignal` automatically subscribes and unsubscribes within the injection context, eliminating the need for `async` pipe or manual subscription management.

❌ **Wrong — manually subscribing to an Observable in a signal-based component:**
```typescript
users$  = this.http.get<User[]>('/api/users');
users: User[] = [];
ngOnInit() { this.users$.subscribe(u => this.users = u); } // manual cleanup needed
```

✅ **Correct — toSignal bridges Observable to signal:**
```typescript
import { toSignal, toObservable } from '@angular/core/rxjs-interop';

@Component({
  template: `
    <div *ngFor="let user of users()">{{ user.name }}</div>
    <p *ngIf="users.isLoading()">Loading...</p>
  `
})
export class UserListComponent {
  private svc = inject(UserService);

  // Observable → Signal: auto-subscribes and cleans up
  users = toSignal(this.svc.getUsers(), { initialValue: [] as User[] });

  // Signal → Observable (for operators):
  searchTerm = signal('');
  results    = toSignal(
    toObservable(this.searchTerm).pipe(
      debounceTime(300),
      switchMap(term => this.svc.search(term))
    ),
    { initialValue: [] as User[] }
  );
}
```

---

## 7.3 Angular 17+ Control Flow & Deferrable Views

### Q50. What are the built-in control flow blocks (@if, @for, @switch) introduced in Angular 17?

**Answer:**
Angular 17 introduced a new template syntax that replaces `*ngIf`, `*ngFor`, and `*ngSwitch` structural directives. The new `@if`, `@for`, and `@switch` blocks are **built into the Angular compiler** — no import required. `@for` requires a `track` expression (replaces `trackBy`). They improve performance (no extra DOM nodes), readability, and enable better type-narrowing in templates.

❌ **Old approach — structural directives (still valid but deprecated in favour of new syntax):**
```html
<!-- Requires CommonModule or NgIf/NgFor imports -->
<div *ngIf="user; else loading">{{ user.name }}</div>
<ng-template #loading>Loading...</ng-template>

<ul>
  <li *ngFor="let item of items; trackBy: trackById">{{ item.name }}</li>
</ul>

<ng-container [ngSwitch]="status">
  <span *ngSwitchCase="'active'">Active</span>
  <span *ngSwitchDefault>Unknown</span>
</ng-container>
```

✅ **New control flow (Angular 17+) — no imports needed:**
```html
<!-- @if with @else and type narrowing -->
@if (user) {
  <p>{{ user.name }}</p>     <!-- user is narrowed to non-null here -->
} @else if (isLoading) {
  <app-spinner />
} @else {
  <p>Not found</p>
}

<!-- @for with required track -->
@for (item of items; track item.id) {
  <li>{{ item.name }}</li>
} @empty {
  <li>No items found</li>    <!-- @empty block for empty collections -->
}

<!-- @switch -->
@switch (status) {
  @case ('active')   { <span class="green">Active</span> }
  @case ('inactive') { <span class="red">Inactive</span> }
  @default           { <span>Unknown</span> }
}
```

---

### Q51. What is `@defer` and how does it enable deferrable views?

**Answer:**
`@defer` (Angular 17+) lazily loads a component's template chunk only when a trigger condition is met. This defers JavaScript download and parsing, improving initial page load. Triggers include `on idle` (browser idle), `on viewport` (element enters viewport), `on interaction` (user clicks/focusses), `on timer(n)`, and `when condition`. `@placeholder` shows content before loading; `@loading` shows during download; `@error` shows on failure.

❌ **Wrong — eagerly bundling and rendering heavy components on page load:**
```html
<!-- HeavyChartComponent is downloaded even if user never scrolls to it -->
<app-heavy-chart [data]="data"></app-heavy-chart>
```

✅ **Correct — defer heavy components until needed:**
```html
<!-- Defer until viewport — chart only downloaded when scrolled into view -->
@defer (on viewport) {
  <app-heavy-chart [data]="data" />
} @placeholder {
  <div class="chart-placeholder">📊 Chart loading...</div>
} @loading (minimum 200ms) {
  <app-spinner />
} @error {
  <p>Chart failed to load</p>
}

<!-- Defer until browser is idle — non-critical components -->
@defer (on idle) {
  <app-recommendations />
}

<!-- Defer until user interacts with the trigger element -->
@defer (on interaction(triggerRef)) {
  <app-comments />
} @placeholder {
  <button #triggerRef>Load Comments</button>
}

<!-- Conditional defer -->
@defer (when isLoggedIn) {
  <app-user-dashboard />
}
```

---

# 8. Pipes

> 📚 Reference: https://angular.dev/guide/pipes

---

## 8.1 Built-in & Custom Pipes

### Q52. What are the most commonly used built-in Angular pipes?

**Answer:**
`date`, `currency`, `number`, `percent`, `uppercase`/`lowercase`/`titlecase`, `json` (debugging), `slice`, `keyvalue` (object to key-value pairs), `async` (subscribes to Observable or Promise), and `i18nPlural`/`i18nSelect`. The `async` pipe is the most important — it handles subscription and unsubscription automatically, preventing memory leaks.

❌ **Wrong — manually subscribing to an Observable in the component (memory leak risk):**
```typescript
users: User[] = [];
ngOnInit() {
  this.userSvc.getUsers().subscribe(u => this.users = u); // must unsubscribe manually
}
// Template: {{ users | json }}
```

✅ **Correct — async pipe manages the subscription:**
```html
<!-- Template — async pipe subscribes and unsubscribes automatically -->
@if (users$ | async; as users) {
  @for (user of users; track user.id) {
    <div>{{ user.name | titlecase }} — {{ user.joinDate | date:'mediumDate' }}</div>
    <div>{{ user.salary | currency:'USD':'symbol':'1.0-0' }}</div>
    <div>{{ user.score | number:'1.1-2' }}%</div>
  }
}
```

---

### Q53. How do you create a custom pipe? What is the difference between pure and impure pipes?

**Answer:**
A pure pipe (default) recalculates **only when the input reference changes** — Angular caches the result. An impure pipe recalculates on **every change detection cycle** regardless of input change. Impure pipes are expensive — use them only when inputs are mutable objects that change internally (e.g., filtering a mutable array). Always prefer immutable data patterns + pure pipes.

❌ **Wrong — impure pipe on a large list triggers on every keypress:**
```typescript
@Pipe({ name: 'filter', pure: false }) // impure — runs EVERY CD cycle
export class FilterPipe implements PipeTransform {
  transform(items: Product[], term: string) {
    return items.filter(p => p.name.includes(term)); // called 100s of times/second
  }
}
```

✅ **Correct — pure pipe with immutable filtering:**
```typescript
// Pure custom pipe (default)
@Pipe({ name: 'truncate', standalone: true })
export class TruncatePipe implements PipeTransform {
  transform(value: string, limit = 100, suffix = '…'): string {
    if (!value || value.length <= limit) return value;
    return value.substring(0, limit).trimEnd() + suffix;
  }
}

// Usage
// {{ product.description | truncate:50 }}
// {{ longText | truncate:200:'... read more' }}

// For filtering — filter in the component, not a pipe:
@Component({ template: `@for (p of filteredProducts(); track p.id) { ... }` })
export class ProductListComponent {
  private products = signal<Product[]>([]);
  filter = signal('');
  filteredProducts = computed(() =>
    this.products().filter(p => p.name.toLowerCase().includes(this.filter().toLowerCase()))
  );
}
```

---

# 9. HTTP & Interceptors

> 📚 Reference: https://angular.dev/guide/http
> 📚 Interceptors: https://angular.dev/guide/http/interceptors

---

## 9.1 HttpClient

### Q54. How do you use `HttpClient` for GET, POST, PUT, and DELETE requests?

**Answer:**
`HttpClient` is Angular's HTTP service. Methods return cold Observables — they only execute when subscribed. Always provide a typed generic parameter for type safety. For error handling, use `catchError`. For loading states, use `finalize`. Register `provideHttpClient()` in your app providers (standalone) or import `HttpClientModule` (module-based).

❌ **Wrong — ignoring error handling and type safety:**
```typescript
getData() {
  return this.http.get('/api/orders'); // untyped any
}
// If request fails, Observable errors and crashes subscribers
```

✅ **Correct — typed, with error handling:**
```typescript
@Injectable({ providedIn: 'root' })
export class OrderService {
  private http = inject(HttpClient);
  private baseUrl = '/api/orders';

  getAll(): Observable<Order[]> {
    return this.http.get<Order[]>(this.baseUrl).pipe(
      catchError(this.handleError)
    );
  }

  getById(id: string): Observable<Order> {
    return this.http.get<Order>(`${this.baseUrl}/${id}`);
  }

  create(order: CreateOrderDto): Observable<Order> {
    return this.http.post<Order>(this.baseUrl, order);
  }

  update(id: string, dto: UpdateOrderDto): Observable<Order> {
    return this.http.put<Order>(`${this.baseUrl}/${id}`, dto);
  }

  delete(id: string): Observable<void> {
    return this.http.delete<void>(`${this.baseUrl}/${id}`);
  }

  private handleError(err: HttpErrorResponse): Observable<never> {
    const msg = err.status === 0
      ? 'Network error — check your connection'
      : `Server error ${err.status}: ${err.message}`;
    return throwError(() => new Error(msg));
  }
}
```

---

### Q55. What are HTTP interceptors and how do you create a functional interceptor (Angular 15+)?

**Answer:**
Interceptors intercept every `HttpRequest` and `HttpResponse` to add cross-cutting behaviour: auth tokens, logging, error handling, loading spinners. Angular 15+ supports **functional interceptors** — a plain function instead of a class, compatible with standalone apps. Registered via `withInterceptors()` in `provideHttpClient()`.

❌ **Wrong — setting auth token per request in every service method:**
```typescript
getOrders() {
  const token = this.auth.getToken();
  const headers = new HttpHeaders({ Authorization: `Bearer ${token}` });
  return this.http.get<Order[]>('/api/orders', { headers }); // repeated everywhere
}
```

✅ **Correct — functional interceptors for cross-cutting concerns:**
```typescript
// auth.interceptor.ts
import { HttpInterceptorFn, HttpErrorResponse } from '@angular/common/http';
import { inject } from '@angular/core';
import { catchError, throwError } from 'rxjs';

export const authInterceptor: HttpInterceptorFn = (req, next) => {
  const auth  = inject(AuthService);
  const token = auth.getToken();

  const authReq = token
    ? req.clone({ headers: req.headers.set('Authorization', `Bearer ${token}`) })
    : req;

  return next(authReq);
};

export const errorInterceptor: HttpInterceptorFn = (req, next) => {
  const router = inject(Router);
  return next(req).pipe(
    catchError((err: HttpErrorResponse) => {
      if (err.status === 401) router.navigate(['/login']);
      if (err.status === 403) router.navigate(['/forbidden']);
      return throwError(() => err);
    })
  );
};

export const loadingInterceptor: HttpInterceptorFn = (req, next) => {
  const loading = inject(LoadingService);
  loading.show();
  return next(req).pipe(finalize(() => loading.hide()));
};

// Registration (standalone):
bootstrapApplication(AppComponent, {
  providers: [
    provideHttpClient(
      withInterceptors([authInterceptor, errorInterceptor, loadingInterceptor])
    )
  ]
});
```

---

### Q56. How do you handle HTTP errors globally and retry failed requests?

**Answer:**
Use `catchError` to handle errors per-request or an interceptor for global handling. Use `retry()` or `retryWhen()` for automatic retry with exponential backoff. For idempotent GET requests, retry up to 3 times. Never retry POST/DELETE blindly — could duplicate mutations.

❌ **Wrong — swallowing errors silently:**
```typescript
getData() {
  return this.http.get('/api/data').pipe(
    catchError(() => of([]))  // returns empty, user has no idea what failed
  );
}
```

✅ **Correct — retry idempotent requests, surface errors clearly:**
```typescript
import { retry, catchError, throwError, timer } from 'rxjs';

getOrders(): Observable<Order[]> {
  return this.http.get<Order[]>('/api/orders').pipe(
    retry({
      count: 3,
      delay: (error, retryCount) => {
        if (error.status === 404) throwError(() => error); // don't retry 404
        return timer(1000 * retryCount); // 1s, 2s, 3s exponential backoff
      }
    }),
    catchError((err: HttpErrorResponse) => {
      this.notificationSvc.error(`Failed to load orders: ${err.message}`);
      return throwError(() => err); // re-throw for component to handle if needed
    })
  );
}
```

---

# 10. Angular Compilation, Build & Optimization

> 📚 Reference: https://angular.dev/tools/cli/build
> 📚 AOT: https://angular.dev/tools/cli/aot-compiler

---

## 10.1 Compilation

### Q57. What is AOT (Ahead-of-Time) compilation and why is it the default?

**Answer:**
AOT compiles Angular templates at **build time** into optimised JavaScript. JIT (Just-in-Time) compiled at runtime in the browser. AOT benefits: smaller bundle (Angular compiler not shipped), faster startup (no compile step at runtime), earlier template error detection (build fails instead of runtime error), and better tree-shaking. AOT is the default since Angular 9 (Ivy).

❌ **Wrong — using JIT in production (larger bundle, slower startup, late error detection):**
```json
// angular.json — disabling AOT
"configurations": {
  "production": { "aot": false }
}
// Template errors only surface at runtime in users' browsers
```

✅ **Correct — AOT is default; common AOT-compatibility rules:**
```typescript
// ✅ DOM access must be done through Angular, not directly (breaks SSR + AOT):
// ❌ document.getElementById('btn').click();
// ✅ Use @ViewChild + ElementRef or Renderer2 instead

// ✅ Exported functions in templates must be pure and exportable:
// ❌ Template: {{ this.privateMethod() }} — private methods not accessible in AOT
// ✅ Template: {{ publicMethod() }} — use public methods or pipes

// ✅ Dynamic component types must be known at compile time for tree-shaking:
import { AdminComponent } from './admin.component'; // static import ✅
// import(path) // only for lazy routes, not arbitrary dynamic types
```

---

### Q58. What are the key strategies for reducing Angular bundle size?

**Answer:**
Reduce bundle size with: lazy loading routes and components, standalone components (better tree-shaking than NgModules), `@defer` for heavy third-party components, avoiding importing entire libraries (import only what you use), enabling production mode (minification, tree-shaking), using `ng build --configuration production`, and analysing the bundle with `source-map-explorer` or `webpack-bundle-analyzer`.

❌ **Wrong — importing entire icon library:**
```typescript
import { MatIconModule } from '@angular/material/icon';
import * as Icons from '@fortawesome/free-solid-svg-icons'; // entire icon pack
```

✅ **Correct — targeted imports and lazy loading:**
```typescript
// Import only specific icons
import { faUser, faHome, faCog } from '@fortawesome/free-solid-svg-icons';

// Analyse bundle (run after build):
// npx source-map-explorer dist/my-app/*.js

// Angular CLI build with stats:
// ng build --stats-json
// npx webpack-bundle-analyzer dist/my-app/stats.json

// Standalone components are automatically tree-shaken:
@Component({
  standalone: true,
  imports: [
    CurrencyPipe,    // only this pipe, not all CommonModule pipes
    DatePipe,
    RouterLink
  ]
})
export class ProductCardComponent {}
```

---

### Q59. What is Angular Universal (SSR) and when should you use it?

**Answer:**
Angular Universal enables **Server-Side Rendering (SSR)** — the initial HTML is rendered on the server and sent to the browser before JavaScript loads. This improves Time to First Contentful Paint, enables SEO (search engine crawlers see real content), and improves performance on low-powered devices. Angular 17 ships with SSR built in via `@angular/ssr`. Use for public-facing apps that need SEO; skip for authenticated dashboards.

❌ **Wrong — SPA-only for a public e-commerce site (crawlers see empty HTML):**
```html
<!-- What Googlebot sees without SSR -->
<html>
  <body>
    <app-root></app-root>  <!-- empty until JS loads — not indexed! -->
  </body>
</html>
```

✅ **Correct — SSR with Angular 17:**
```bash
# Create new SSR project
ng new my-app --ssr

# Add SSR to existing project
ng add @angular/ssr
```

```typescript
// server.ts — Express server for SSR
import { APP_BASE_HREF } from '@angular/common';
import { CommonEngine }  from '@angular/ssr';
import express from 'express';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';
import bootstrap from './src/main.server';

export function app(): express.Express {
  const server      = express();
  const commonEngine = new CommonEngine();

  server.get('*', (req, res, next) => {
    commonEngine.render({
      bootstrap,
      documentFilePath: join(serverDistFolder, 'index.html'),
      url: req.originalUrl,
      publicPath: browserDistFolder,
      providers: [{ provide: APP_BASE_HREF, useValue: req.baseUrl }],
    }).then(html => res.send(html)).catch(next);
  });

  return server;
}
```

---

### Q60. How does `trackBy` (or `track` in new control flow) improve `@for` performance?

**Answer:**
Without `trackBy`/`track`, Angular destroys and recreates every DOM element whenever the array reference changes — even if only one item was added. With `track`, Angular identifies elements by their unique key and only creates/destroys/moves the elements that actually changed. Critical for large lists or lists that update frequently.

❌ **Wrong — no trackBy on a list that refreshes every 5 seconds:**
```html
<!-- Every refresh destroys and recreates 1000 DOM nodes — janky UX -->
<tr *ngFor="let order of orders">{{ order.id }}</tr>
```

✅ **Correct — track by stable identity:**
```html
<!-- New syntax (Angular 17+) — track is required, compiler enforces it -->
@for (order of orders; track order.id) {
  <tr><td>{{ order.id }}</td><td>{{ order.status }}</td></tr>
}

<!-- Old syntax — trackBy is a method reference -->
<tr *ngFor="let order of orders; trackBy: trackById">{{ order.id }}</tr>
```

```typescript
// Old syntax helper (not needed with new @for)
trackById(_: number, order: Order) { return order.id; }
```

---

*Last updated: 2026 | Angular 17+ / Signals / New Control Flow / SSR*

### Q25. What is the singleton pattern in Angular services? How do you ensure a service is truly a singleton?

**Answer:**
A service is a singleton when only one instance exists per injector. With `providedIn: 'root'`, Angular creates one instance for the root injector. The risk of multiple instances arises when a service is provided in both the root module and a lazy-loaded module, or declared in a shared module's `providers`. Use `forRoot()` pattern or `providedIn: 'root'` to guarantee a singleton.

❌ **Wrong — providing a service in SharedModule.providers causes multiple instances when SharedModule is imported in lazy modules:**
```typescript
@NgModule({
  providers: [UserService] // Every module that imports SharedModule gets its own instance!
})
export class SharedModule {}
```

✅ **Correct — forRoot pattern:**
```typescript
@NgModule({
  // No providers here — don't put services here
})
export class SharedModule {
  static forRoot(): ModuleWithProviders<SharedModule> {
    return {
      ngModule: SharedModule,
      providers: [UserService] // Only registered once when called from AppModule
    };
  }
}

// AppModule:
imports: [SharedModule.forRoot()]

// LazyModule:
imports: [SharedModule] // No forRoot — no duplicate provider

// Better: just use providedIn: 'root'
@Injectable({ providedIn: 'root' })
export class UserService {}
```

---

### Q26. How does DI work in lazy-loaded modules? What are the scoping implications?

**Answer:**
Lazy-loaded modules create their own child injector. Services provided in a lazy module's `providers` array are scoped to that module's injector and its components — they are not shared with eagerly loaded modules. Services with `providedIn: 'root'` remain singletons regardless of lazy loading. This is important for security (user session data shouldn't leak between modules) and memory management.

❌ **Wrong — expecting lazy module service to be accessible in eager module:**
```typescript
@NgModule({
  providers: [CartService] // Only available in LazyShopModule and its children
})
export class LazyShopModule {}

// In AppComponent (eager) — ERROR: CartService not found
constructor(private cart: CartService) {}
```

✅ **Correct — understanding scope:**
```typescript
// Singleton service — available everywhere regardless of lazy loading
@Injectable({ providedIn: 'root' })
export class AuthService {}

// Lazy-scoped service — only in lazy module's component tree
@Injectable()
export class CartService {}

@NgModule({
  providers: [CartService] // Available only within LazyShopModule's injector
})
export class LazyShopModule {}

// If cart needs to talk to auth, inject AuthService (root) within CartService
@Injectable()
export class CartService {
  constructor(private auth: AuthService) {} // AuthService is root — always available
}
```

---

### Q27. What is the inject() function (Angular 14+) and how does it differ from constructor injection?

**Answer:**
The `inject()` function is a functional approach to dependency injection that can be used in the injection context (constructor, field initializer, factory function). It eliminates the need for `@Inject` decorator for `InjectionToken`s and simplifies inheritance. It enables DI in standalone functions and is the preferred API in modern Angular, especially with functional guards and resolvers.

❌ **Wrong — using constructor injection for every dependency in complex hierarchies:**
```typescript
export class BaseComponent {
  constructor(protected router: Router) {}
}
export class ChildComponent extends BaseComponent {
  constructor(router: Router, private service: MyService) {
    super(router); // Must pass all base class deps manually
  }
}
```

✅ **Correct with inject():**
```typescript
import { inject, Component } from '@angular/core';
import { Router } from '@angular/router';

export class BaseComponent {
  protected router = inject(Router); // No constructor needed
}

export class ChildComponent extends BaseComponent {
  private service = inject(MyService); // No super() call needed
  private config = inject(APP_CONFIG); // InjectionToken without @Inject
}

// Functional guard (Angular 15+)
export const authGuard = () => {
  const auth = inject(AuthService);
  const router = inject(Router);
  return auth.isLoggedIn() || router.createUrlTree(['/login']);
};
```

---

### Q28. How do you mock services in Angular unit tests?

**Answer:**
Mock services in tests using `TestBed.configureTestingModule` with `providers` using `useValue` (a plain object mock), `useClass` (a mock class), or spy objects created with `jasmine.createSpyObj`. Prefer spy objects for fine-grained control of return values. Avoid actually calling HTTP or external APIs in unit tests.

❌ **Wrong — using real service in unit tests (makes tests slow and fragile):**
```typescript
TestBed.configureTestingModule({
  imports: [HttpClientModule], // Real HTTP — tests make actual requests!
  providers: [UserService]
});
```

✅ **Correct:**
```typescript
describe('UserComponent', () => {
  let mockUserService: jasmine.SpyObj<UserService>;

  beforeEach(() => {
    mockUserService = jasmine.createSpyObj('UserService', ['getUser', 'saveUser']);
    mockUserService.getUser.and.returnValue(of({ id: 1, name: 'Alice' }));

    TestBed.configureTestingModule({
      declarations: [UserComponent],
      providers: [
        { provide: UserService, useValue: mockUserService }
      ]
    });
  });

  it('should load user on init', () => {
    const fixture = TestBed.createComponent(UserComponent);
    fixture.detectChanges();
    expect(mockUserService.getUser).toHaveBeenCalled();
  });
});
```

---

### Q29. What are optional dependencies and how do you use @Optional and @Self / @SkipSelf?

**Answer:**
`@Optional()` marks a dependency as optional — if no provider is found, `null` is injected instead of throwing an error. `@Self()` restricts lookup to the current element's injector only. `@SkipSelf()` skips the current injector and starts lookup from the parent. These decorators give fine-grained control over the DI resolution process and are useful for building extensible components that work with or without certain services.

❌ **Wrong — not using @Optional, causing errors when service is absent:**
```typescript
constructor(private theme: ThemeService) {
  // If ThemeService has no provider, Angular throws NullInjectorError
}
```

✅ **Correct:**
```typescript
import { Optional, Self, SkipSelf, Inject } from '@angular/core';

@Component({ selector: 'app-form-field', template: '' })
export class FormFieldComponent {
  constructor(
    @Optional() private theme: ThemeService, // null if not provided
    @Self() @Optional() private controlContainer: ControlContainer, // only this element's injector
    @SkipSelf() private parentForm: NgForm // skip self, get from parent
  ) {
    if (this.theme) {
      // Use theme
    }
  }
}
```

---

### Q30. What is tree-shakeable DI and why does it matter for bundle size?

**Answer:**
Tree-shakeable DI means a service is only included in the final bundle if something actually injects it. Using `providedIn: 'root'` (or a specific module) makes services tree-shakeable because the provider is defined on the service class itself, not in an NgModule's `providers` array. NgModule `providers` arrays are always included in the bundle regardless of usage, potentially adding dead code.

❌ **Wrong — registering services in NgModule providers (not tree-shakeable):**
```typescript
@NgModule({
  providers: [
    AnalyticsService, // Always bundled, even if never injected
    LegacyService,    // Dead code included in bundle
  ]
})
export class AppModule {}
```

✅ **Correct — tree-shakeable:**
```typescript
@Injectable({
  providedIn: 'root' // Only included if actually injected somewhere
})
export class AnalyticsService {
  track(event: string) { /* ... */ }
}

// Tree-shakeable with InjectionToken
export const FEATURE_FLAGS = new InjectionToken<FeatureFlags>('FeatureFlags', {
  providedIn: 'root',
  factory: () => ({ newUI: false, betaFeatures: false })
});
```

