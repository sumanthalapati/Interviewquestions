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

